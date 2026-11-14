/*
=============================================================================
 Procedimiento almacenado: carga de la capa Bronze (Origen -> Bronze)
=============================================================================
 Propósito:
   Carga los archivos CSV de CRM y ERP en las tablas del esquema 'bronze'.
   Para cada tabla:
     1. Vacía la tabla (TRUNCATE)                      -> carga completa
     2. Inserta el archivo con COPY                    -> equivalente a BULK INSERT
     3. Registra archivo de origen y lote por fila     -> trazabilidad
     4. Registra filas y duración en audit.load_log    -> monitoreo

 Manejo de errores:
   Si una tabla falla, se revierte TODA la carga del lote (las tablas quedan
   con los datos de la carga anterior) y el error queda en audit.load_log con
   estado FAILED. Use audit.assert_last_batch_ok('bronze') para verificarlo.

 Parámetros:
   p_dataset_path  Ruta ABSOLUTA de la carpeta de datasets, vista desde el
                   servidor PostgreSQL. Ejemplo: 'C:/datasets'

 Requisitos:
   COPY ... FROM '<archivo>' lee el archivo en el servidor, por lo que el
   usuario debe ser superusuario o tener el rol 'pg_read_server_files', y el
   servicio de PostgreSQL debe tener permiso de lectura sobre la carpeta.

 Uso:
   CALL bronze.load_bronze('C:/datasets');
=============================================================================
*/

CREATE OR REPLACE PROCEDURE bronze.load_bronze(p_dataset_path TEXT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_batch_id       BIGINT    := nextval('audit.batch_id_seq');
    v_batch_start    TIMESTAMP := clock_timestamp();
    v_start          TIMESTAMP;
    v_rows           BIGINT;
    v_columns        TEXT;
    v_file           TEXT;
    v_current_table  TEXT;
    v_path           TEXT := rtrim(replace(p_dataset_path, '\', '/'), '/');
    v_item           RECORD;
BEGIN
    RAISE NOTICE '================================================';
    RAISE NOTICE 'Cargando capa Bronze | lote % | origen: %', v_batch_id, v_path;
    RAISE NOTICE '================================================';

    BEGIN
        FOR v_item IN
            SELECT *
            FROM (VALUES
                (1, 'CRM', 'crm_cust_info',     'source_crm/cust_info.csv'),
                (2, 'CRM', 'crm_prd_info',      'source_crm/prd_info.csv'),
                (3, 'CRM', 'crm_sales_details', 'source_crm/sales_details.csv'),
                (4, 'ERP', 'erp_cust_az12',     'source_erp/CUST_AZ12.csv'),
                (5, 'ERP', 'erp_loc_a101',      'source_erp/LOC_A101.csv'),
                (6, 'ERP', 'erp_px_cat_g1v2',   'source_erp/PX_CAT_G1V2.csv')
            ) AS t(load_order, source_system, table_name, file_name)
            ORDER BY load_order
        LOOP
            v_start         := clock_timestamp();
            v_current_table := 'bronze.' || v_item.table_name;
            v_file          := v_path || '/' || v_item.file_name;

            -- Columnas de negocio (las columnas técnicas dwh_ no vienen en el CSV)
            SELECT string_agg(quote_ident(column_name), ', ' ORDER BY ordinal_position)
            INTO v_columns
            FROM information_schema.columns
            WHERE table_schema = 'bronze'
              AND table_name   = v_item.table_name
              AND column_name NOT LIKE 'dwh\_%';

            RAISE NOTICE '>> [%] Truncando tabla: %', v_item.source_system, v_current_table;
            EXECUTE format('TRUNCATE TABLE bronze.%I', v_item.table_name);

            RAISE NOTICE '>> [%] Insertando datos en: %', v_item.source_system, v_current_table;
            EXECUTE format(
                'COPY bronze.%I (%s) FROM %L WITH (FORMAT csv, HEADER true, DELIMITER %L, ENCODING %L)',
                v_item.table_name, v_columns, v_file, ',', 'UTF8'
            );

            -- Trazabilidad: archivo de origen y lote de cada registro
            EXECUTE format(
                'UPDATE bronze.%I SET dwh_source_file = %L, dwh_batch_id = %s',
                v_item.table_name, v_item.file_name, v_batch_id
            );
            GET DIAGNOSTICS v_rows = ROW_COUNT;

            INSERT INTO audit.load_log (
                batch_id, layer_name, table_name, source_name, status,
                rows_loaded, rows_rejected, start_time, duration_seconds
            )
            VALUES (
                v_batch_id, 'bronze', v_current_table, v_item.file_name, 'SUCCESS',
                v_rows, 0, v_start,
                round(extract(epoch FROM clock_timestamp() - v_start)::numeric, 3)
            );

            RAISE NOTICE '   Filas cargadas: % | Duración: % s',
                v_rows,
                round(extract(epoch FROM clock_timestamp() - v_start)::numeric, 3);
            RAISE NOTICE '------------------------------------------------';
        END LOOP;

    EXCEPTION
        WHEN OTHERS THEN
            -- Todo lo hecho dentro del bloque se revierte; el fallo sí se registra
            INSERT INTO audit.load_log (
                batch_id, layer_name, table_name, source_name, status,
                start_time, duration_seconds, error_message
            )
            VALUES (
                v_batch_id, 'bronze', v_current_table, v_file, 'FAILED',
                v_batch_start,
                round(extract(epoch FROM clock_timestamp() - v_batch_start)::numeric, 3),
                SQLSTATE || ': ' || SQLERRM
            );

            RAISE WARNING '================================================';
            RAISE WARNING 'ERROR durante la carga de la capa Bronze (lote %)', v_batch_id;
            RAISE WARNING 'Tabla  : %', v_current_table;
            RAISE WARNING 'Mensaje: %', SQLERRM;
            RAISE WARNING 'Código : %', SQLSTATE;
            RAISE WARNING 'Carga revertida. Detalle en audit.load_log';
            RAISE WARNING '================================================';
            RETURN;
    END;

    RAISE NOTICE '================================================';
    RAISE NOTICE 'Carga de la capa Bronze completada (lote %)', v_batch_id;
    RAISE NOTICE '   Duración total: % s',
        round(extract(epoch FROM clock_timestamp() - v_batch_start)::numeric, 3);
    RAISE NOTICE '================================================';
END;
$$;

COMMENT ON PROCEDURE bronze.load_bronze(TEXT)
    IS 'Carga completa (truncate & insert) de los CSV de CRM y ERP en la capa Bronze, con trazabilidad y auditoría';
