/*
=============================================================================
 Procedimiento almacenado: carga de la capa Silver (Bronze -> Silver)
=============================================================================
 Propósito:
   Proceso ETL que limpia, estandariza y enriquece los datos de 'bronze' y
   los carga en 'silver' mediante carga completa (TRUNCATE + INSERT).

 Transformaciones principales:
   - Eliminación de duplicados (último registro por cliente)
   - Recorte de espacios (TRIM) y normalización de códigos
   - Conversión de tipos (enteros yyyymmdd -> DATE)
   - Columnas derivadas (cat_id, prd_key) y fechas de vigencia
   - Corrección de importes de ventas inconsistentes
   - Estandarización de claves para integrar CRM con ERP

 Buenas prácticas de operación:
   - Trazabilidad : cada fila guarda dwh_batch_id (lote) y dwh_create_date
   - Calidad      : los registros RECHAZADOS o CORREGIDOS se guardan con su
                    motivo y el registro original en audit.rejected_records
   - Monitoreo    : filas cargadas, rechazadas y duración en audit.load_log
   - Errores      : ante un fallo se revierte todo el lote y se registra
                    el error (estado FAILED)

 Uso:
   CALL silver.load_silver();
=============================================================================
*/

CREATE OR REPLACE PROCEDURE silver.load_silver()
LANGUAGE plpgsql
AS $$
DECLARE
    v_batch_id       BIGINT    := nextval('audit.batch_id_seq');
    v_batch_start    TIMESTAMP := clock_timestamp();
    v_start          TIMESTAMP;
    v_rows           BIGINT;
    v_rejected       BIGINT;
    v_current_table  TEXT;
BEGIN
    RAISE NOTICE '================================================';
    RAISE NOTICE 'Cargando capa Silver | lote %', v_batch_id;
    RAISE NOTICE '================================================';

    BEGIN
        -- ===================================================================
        -- CRM: clientes
        -- ===================================================================
        v_start := clock_timestamp();
        v_current_table := 'silver.crm_cust_info';
        RAISE NOTICE '>> Truncando e insertando: %', v_current_table;

        -- Calidad: registros descartados (clave nula o duplicada)
        INSERT INTO audit.rejected_records
            (batch_id, layer_name, table_name, record_key, action_taken, reason, record_data)
        SELECT v_batch_id, 'silver', v_current_table, cst_id::text, 'REJECTED',
               CASE WHEN cst_id IS NULL THEN 'Clave primaria cst_id nula'
                    ELSE 'cst_id duplicado: se conserva el registro más reciente' END,
               to_jsonb(t) - 'rn'
        FROM (
            SELECT b.*,
                   row_number() OVER (PARTITION BY cst_id
                                      ORDER BY cst_create_date DESC NULLS LAST) AS rn
            FROM bronze.crm_cust_info b
        ) t
        WHERE cst_id IS NULL OR rn > 1;
        GET DIAGNOSTICS v_rejected = ROW_COUNT;

        TRUNCATE TABLE silver.crm_cust_info;

        INSERT INTO silver.crm_cust_info (
            cst_id, cst_key, cst_firstname, cst_lastname,
            cst_marital_status, cst_gndr, cst_create_date, dwh_batch_id
        )
        SELECT
            cst_id,
            trim(cst_key),
            trim(cst_firstname),
            trim(cst_lastname),
            CASE upper(trim(cst_marital_status))
                WHEN 'S' THEN 'Single'
                WHEN 'M' THEN 'Married'
                ELSE 'n/a'
            END,
            CASE upper(trim(cst_gndr))
                WHEN 'F' THEN 'Female'
                WHEN 'M' THEN 'Male'
                ELSE 'n/a'
            END,
            cst_create_date,
            v_batch_id
        FROM (
            SELECT *,
                   row_number() OVER (PARTITION BY cst_id
                                      ORDER BY cst_create_date DESC NULLS LAST) AS rn
            FROM bronze.crm_cust_info
            WHERE cst_id IS NOT NULL
        ) t
        WHERE rn = 1;   -- se conserva el registro más reciente de cada cliente
        GET DIAGNOSTICS v_rows = ROW_COUNT;

        INSERT INTO audit.load_log (batch_id, layer_name, table_name, source_name, status,
                                    rows_loaded, rows_rejected, start_time, duration_seconds)
        VALUES (v_batch_id, 'silver', v_current_table, 'bronze.crm_cust_info', 'SUCCESS',
                v_rows, v_rejected, v_start,
                round(extract(epoch FROM clock_timestamp() - v_start)::numeric, 3));
        RAISE NOTICE '   Filas: % | Rechazadas: % | Duración: % s', v_rows, v_rejected,
            round(extract(epoch FROM clock_timestamp() - v_start)::numeric, 3);

        -- ===================================================================
        -- CRM: productos
        -- ===================================================================
        v_start := clock_timestamp();
        v_current_table := 'silver.crm_prd_info';
        RAISE NOTICE '>> Truncando e insertando: %', v_current_table;

        -- Calidad: registros corregidos
        INSERT INTO audit.rejected_records
            (batch_id, layer_name, table_name, record_key, action_taken, reason, record_data)
        SELECT v_batch_id, 'silver', v_current_table, b.prd_key, 'CORRECTED', r.reason, to_jsonb(b)
        FROM bronze.crm_prd_info b
        CROSS JOIN LATERAL (
            SELECT 'Costo nulo o negativo reemplazado por 0' AS reason
            WHERE b.prd_cost IS NULL OR b.prd_cost < 0
            UNION ALL
            SELECT 'Fecha fin anterior a fecha inicio: se recalcula con la siguiente versión'
            WHERE b.prd_end_dt < b.prd_start_dt
        ) r;

        TRUNCATE TABLE silver.crm_prd_info;

        INSERT INTO silver.crm_prd_info (
            prd_id, cat_id, prd_key, prd_nm, prd_cost,
            prd_line, prd_start_dt, prd_end_dt, dwh_batch_id
        )
        SELECT
            prd_id,
            replace(substring(prd_key FROM 1 FOR 5), '-', '_'),   -- id de categoría (ERP)
            substring(prd_key FROM 7),                            -- clave del producto
            trim(prd_nm),
            CASE WHEN prd_cost IS NULL OR prd_cost < 0 THEN 0 ELSE prd_cost END,
            CASE upper(trim(prd_line))
                WHEN 'M' THEN 'Mountain'
                WHEN 'R' THEN 'Road'
                WHEN 'S' THEN 'Other Sales'
                WHEN 'T' THEN 'Touring'
                ELSE 'n/a'
            END,
            prd_start_dt::DATE,
            -- fin de vigencia = día anterior al inicio de la siguiente versión del producto
            (lead(prd_start_dt) OVER (PARTITION BY prd_key ORDER BY prd_start_dt))::DATE - 1,
            v_batch_id
        FROM bronze.crm_prd_info;
        GET DIAGNOSTICS v_rows = ROW_COUNT;

        INSERT INTO audit.load_log (batch_id, layer_name, table_name, source_name, status,
                                    rows_loaded, rows_rejected, start_time, duration_seconds)
        VALUES (v_batch_id, 'silver', v_current_table, 'bronze.crm_prd_info', 'SUCCESS',
                v_rows, 0, v_start,
                round(extract(epoch FROM clock_timestamp() - v_start)::numeric, 3));
        RAISE NOTICE '   Filas: % | Duración: % s', v_rows,
            round(extract(epoch FROM clock_timestamp() - v_start)::numeric, 3);

        -- ===================================================================
        -- CRM: detalle de ventas
        -- ===================================================================
        v_start := clock_timestamp();
        v_current_table := 'silver.crm_sales_details';
        RAISE NOTICE '>> Truncando e insertando: %', v_current_table;

        -- Calidad: registros corregidos (fechas inválidas e importes inconsistentes)
        INSERT INTO audit.rejected_records
            (batch_id, layer_name, table_name, record_key, action_taken, reason, record_data)
        SELECT v_batch_id, 'silver', v_current_table,
               b.sls_ord_num || '|' || b.sls_prd_key, 'CORRECTED', r.reason, to_jsonb(b)
        FROM bronze.crm_sales_details b
        CROSS JOIN LATERAL (
            SELECT 'Fecha de pedido inválida: se deja en NULL' AS reason
            WHERE b.sls_order_dt <= 0 OR length(b.sls_order_dt::text) <> 8
            UNION ALL
            SELECT 'Fecha de envío inválida: se deja en NULL'
            WHERE b.sls_ship_dt <= 0 OR length(b.sls_ship_dt::text) <> 8
            UNION ALL
            SELECT 'Fecha de vencimiento inválida: se deja en NULL'
            WHERE b.sls_due_dt <= 0 OR length(b.sls_due_dt::text) <> 8
            UNION ALL
            SELECT 'Monto de venta nulo, negativo o distinto de cantidad * precio: se recalcula'
            WHERE b.sls_sales IS NULL OR b.sls_sales <= 0
               OR b.sls_sales <> b.sls_quantity * abs(b.sls_price)
            UNION ALL
            SELECT 'Precio nulo o no positivo: se recalcula como ventas / cantidad'
            WHERE b.sls_price IS NULL OR b.sls_price <= 0
        ) r;

        TRUNCATE TABLE silver.crm_sales_details;

        INSERT INTO silver.crm_sales_details (
            sls_ord_num, sls_prd_key, sls_cust_id,
            sls_order_dt, sls_ship_dt, sls_due_dt,
            sls_sales, sls_quantity, sls_price, dwh_batch_id
        )
        SELECT
            trim(sls_ord_num),
            trim(sls_prd_key),
            sls_cust_id,
            CASE WHEN sls_order_dt <= 0 OR length(sls_order_dt::text) <> 8 THEN NULL
                 ELSE to_date(sls_order_dt::text, 'YYYYMMDD') END,
            CASE WHEN sls_ship_dt  <= 0 OR length(sls_ship_dt::text)  <> 8 THEN NULL
                 ELSE to_date(sls_ship_dt::text,  'YYYYMMDD') END,
            CASE WHEN sls_due_dt   <= 0 OR length(sls_due_dt::text)   <> 8 THEN NULL
                 ELSE to_date(sls_due_dt::text,   'YYYYMMDD') END,
            -- ventas = cantidad * precio cuando el valor original es nulo, negativo o inconsistente
            CASE WHEN sls_sales IS NULL OR sls_sales <= 0
                      OR sls_sales <> sls_quantity * abs(sls_price)
                 THEN sls_quantity * abs(sls_price)
                 ELSE sls_sales END,
            sls_quantity,
            -- precio = ventas / cantidad cuando el valor original es nulo o no positivo
            CASE WHEN sls_price IS NULL OR sls_price <= 0
                 THEN sls_sales / nullif(sls_quantity, 0)
                 ELSE sls_price END,
            v_batch_id
        FROM bronze.crm_sales_details;
        GET DIAGNOSTICS v_rows = ROW_COUNT;

        INSERT INTO audit.load_log (batch_id, layer_name, table_name, source_name, status,
                                    rows_loaded, rows_rejected, start_time, duration_seconds)
        VALUES (v_batch_id, 'silver', v_current_table, 'bronze.crm_sales_details', 'SUCCESS',
                v_rows, 0, v_start,
                round(extract(epoch FROM clock_timestamp() - v_start)::numeric, 3));
        RAISE NOTICE '   Filas: % | Duración: % s', v_rows,
            round(extract(epoch FROM clock_timestamp() - v_start)::numeric, 3);

        -- ===================================================================
        -- ERP: datos adicionales de clientes
        -- ===================================================================
        v_start := clock_timestamp();
        v_current_table := 'silver.erp_cust_az12';
        RAISE NOTICE '>> Truncando e insertando: %', v_current_table;

        INSERT INTO audit.rejected_records
            (batch_id, layer_name, table_name, record_key, action_taken, reason, record_data)
        SELECT v_batch_id, 'silver', v_current_table, b.cid, 'CORRECTED',
               'Fecha de nacimiento futura: se deja en NULL', to_jsonb(b)
        FROM bronze.erp_cust_az12 b
        WHERE b.bdate > current_date;

        TRUNCATE TABLE silver.erp_cust_az12;

        INSERT INTO silver.erp_cust_az12 (cid, bdate, gen, dwh_batch_id)
        SELECT
            CASE WHEN cid LIKE 'NAS%' THEN substring(cid FROM 4)   -- quitar prefijo 'NAS'
                 ELSE cid END,
            CASE WHEN bdate > current_date THEN NULL                -- fechas futuras inválidas
                 ELSE bdate END,
            CASE WHEN upper(trim(gen)) IN ('F', 'FEMALE') THEN 'Female'
                 WHEN upper(trim(gen)) IN ('M', 'MALE')   THEN 'Male'
                 ELSE 'n/a' END,
            v_batch_id
        FROM bronze.erp_cust_az12;
        GET DIAGNOSTICS v_rows = ROW_COUNT;

        INSERT INTO audit.load_log (batch_id, layer_name, table_name, source_name, status,
                                    rows_loaded, rows_rejected, start_time, duration_seconds)
        VALUES (v_batch_id, 'silver', v_current_table, 'bronze.erp_cust_az12', 'SUCCESS',
                v_rows, 0, v_start,
                round(extract(epoch FROM clock_timestamp() - v_start)::numeric, 3));
        RAISE NOTICE '   Filas: % | Duración: % s', v_rows,
            round(extract(epoch FROM clock_timestamp() - v_start)::numeric, 3);

        -- ===================================================================
        -- ERP: ubicación de clientes
        -- ===================================================================
        v_start := clock_timestamp();
        v_current_table := 'silver.erp_loc_a101';
        RAISE NOTICE '>> Truncando e insertando: %', v_current_table;

        INSERT INTO audit.rejected_records
            (batch_id, layer_name, table_name, record_key, action_taken, reason, record_data)
        SELECT v_batch_id, 'silver', v_current_table, b.cid, 'CORRECTED',
               'País vacío: se reemplaza por n/a', to_jsonb(b)
        FROM bronze.erp_loc_a101 b
        WHERE b.cntry IS NULL OR trim(b.cntry) = '';

        TRUNCATE TABLE silver.erp_loc_a101;

        INSERT INTO silver.erp_loc_a101 (cid, cntry, dwh_batch_id)
        SELECT
            replace(cid, '-', ''),                                 -- AW-00011000 -> AW00011000
            CASE WHEN trim(cntry) = 'DE'                THEN 'Germany'
                 WHEN trim(cntry) IN ('US', 'USA')      THEN 'United States'
                 WHEN cntry IS NULL OR trim(cntry) = '' THEN 'n/a'
                 ELSE trim(cntry) END,
            v_batch_id
        FROM bronze.erp_loc_a101;
        GET DIAGNOSTICS v_rows = ROW_COUNT;

        INSERT INTO audit.load_log (batch_id, layer_name, table_name, source_name, status,
                                    rows_loaded, rows_rejected, start_time, duration_seconds)
        VALUES (v_batch_id, 'silver', v_current_table, 'bronze.erp_loc_a101', 'SUCCESS',
                v_rows, 0, v_start,
                round(extract(epoch FROM clock_timestamp() - v_start)::numeric, 3));
        RAISE NOTICE '   Filas: % | Duración: % s', v_rows,
            round(extract(epoch FROM clock_timestamp() - v_start)::numeric, 3);

        -- ===================================================================
        -- ERP: categorías de productos (sin problemas de calidad detectados)
        -- ===================================================================
        v_start := clock_timestamp();
        v_current_table := 'silver.erp_px_cat_g1v2';
        RAISE NOTICE '>> Truncando e insertando: %', v_current_table;
        TRUNCATE TABLE silver.erp_px_cat_g1v2;

        INSERT INTO silver.erp_px_cat_g1v2 (id, cat, subcat, maintenance, dwh_batch_id)
        SELECT trim(id), trim(cat), trim(subcat), trim(maintenance), v_batch_id
        FROM bronze.erp_px_cat_g1v2;
        GET DIAGNOSTICS v_rows = ROW_COUNT;

        INSERT INTO audit.load_log (batch_id, layer_name, table_name, source_name, status,
                                    rows_loaded, rows_rejected, start_time, duration_seconds)
        VALUES (v_batch_id, 'silver', v_current_table, 'bronze.erp_px_cat_g1v2', 'SUCCESS',
                v_rows, 0, v_start,
                round(extract(epoch FROM clock_timestamp() - v_start)::numeric, 3));
        RAISE NOTICE '   Filas: % | Duración: % s', v_rows,
            round(extract(epoch FROM clock_timestamp() - v_start)::numeric, 3);

    EXCEPTION
        WHEN OTHERS THEN
            -- Todo lo hecho dentro del bloque se revierte; el fallo sí se registra
            INSERT INTO audit.load_log (batch_id, layer_name, table_name, status,
                                        start_time, duration_seconds, error_message)
            VALUES (v_batch_id, 'silver', v_current_table, 'FAILED', v_batch_start,
                    round(extract(epoch FROM clock_timestamp() - v_batch_start)::numeric, 3),
                    SQLSTATE || ': ' || SQLERRM);

            RAISE WARNING '================================================';
            RAISE WARNING 'ERROR durante la carga de la capa Silver (lote %)', v_batch_id;
            RAISE WARNING 'Tabla  : %', v_current_table;
            RAISE WARNING 'Mensaje: %', SQLERRM;
            RAISE WARNING 'Código : %', SQLSTATE;
            RAISE WARNING 'Carga revertida. Detalle en audit.load_log';
            RAISE WARNING '================================================';
            RETURN;
    END;

    RAISE NOTICE '================================================';
    RAISE NOTICE 'Carga de la capa Silver completada (lote %)', v_batch_id;
    RAISE NOTICE '   Duración total: % s',
        round(extract(epoch FROM clock_timestamp() - v_batch_start)::numeric, 3);
    RAISE NOTICE '================================================';
END;
$$;

COMMENT ON PROCEDURE silver.load_silver()
    IS 'Carga completa de Silver: limpieza, estandarización y enriquecimiento desde Bronze, con auditoría de calidad';
