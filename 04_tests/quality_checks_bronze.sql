/*
=============================================================================
 Validaciones: capa Bronze
=============================================================================
 Propósito:
   Verificar la completitud de la ingesta y la estructura (schema checks)
   después de ejecutar CALL bronze.load_bronze(...).
   Estas consultas NO corrigen datos: en Bronze los datos se conservan tal
   como llegan. Los problemas detectados se tratan en la capa Silver.
=============================================================================
*/

-- ---------------------------------------------------------------------------
-- 1. Completitud: filas cargadas vs. filas esperadas en los CSV (sin encabezado)
--    Resultado esperado: diferencia = 0 en todas las tablas
-- ---------------------------------------------------------------------------
SELECT table_name, expected_rows, loaded_rows, loaded_rows - expected_rows AS row_difference
FROM (
    SELECT 'crm_cust_info'     AS table_name, 18494 AS expected_rows, (SELECT count(*) FROM bronze.crm_cust_info)     AS loaded_rows UNION ALL
    SELECT 'crm_prd_info',                397,               (SELECT count(*) FROM bronze.crm_prd_info)                  UNION ALL
    SELECT 'crm_sales_details',         60398,               (SELECT count(*) FROM bronze.crm_sales_details)             UNION ALL
    SELECT 'erp_cust_az12',             18484,               (SELECT count(*) FROM bronze.erp_cust_az12)                 UNION ALL
    SELECT 'erp_loc_a101',              18484,               (SELECT count(*) FROM bronze.erp_loc_a101)                  UNION ALL
    SELECT 'erp_px_cat_g1v2',              37,               (SELECT count(*) FROM bronze.erp_px_cat_g1v2)
) AS t;

-- ---------------------------------------------------------------------------
-- 2. Estructura: columnas y tipos de cada tabla Bronze
-- ---------------------------------------------------------------------------
SELECT table_name, ordinal_position, column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'bronze'
ORDER BY table_name, ordinal_position;

-- ---------------------------------------------------------------------------
-- 3. Columnas desplazadas: la primera y última columna no deben venir vacías
--    en masa (indicaría un delimitador o encabezado incorrecto)
-- ---------------------------------------------------------------------------
SELECT 'crm_cust_info' AS table_name, count(*) FILTER (WHERE cst_key IS NULL)        AS null_keys FROM bronze.crm_cust_info     UNION ALL
SELECT 'crm_prd_info',           count(*) FILTER (WHERE prd_key IS NULL)                        FROM bronze.crm_prd_info      UNION ALL
SELECT 'crm_sales_details',      count(*) FILTER (WHERE sls_ord_num IS NULL)                    FROM bronze.crm_sales_details UNION ALL
SELECT 'erp_cust_az12',          count(*) FILTER (WHERE cid IS NULL)                            FROM bronze.erp_cust_az12     UNION ALL
SELECT 'erp_loc_a101',           count(*) FILTER (WHERE cid IS NULL)                            FROM bronze.erp_loc_a101      UNION ALL
SELECT 'erp_px_cat_g1v2',        count(*) FILTER (WHERE id IS NULL)                             FROM bronze.erp_px_cat_g1v2;

-- ---------------------------------------------------------------------------
-- 4. Trazabilidad: toda fila tiene fecha de carga, archivo de origen y lote
--    Resultado esperado: sin_trazabilidad = 0 y un único lote por tabla
-- ---------------------------------------------------------------------------
SELECT 'crm_cust_info' AS table_name,
       count(*) FILTER (WHERE dwh_load_date IS NULL OR dwh_source_file IS NULL OR dwh_batch_id IS NULL) AS rows_without_traceability,
       count(DISTINCT dwh_batch_id) AS batches
FROM bronze.crm_cust_info UNION ALL
SELECT 'crm_prd_info',      count(*) FILTER (WHERE dwh_load_date IS NULL OR dwh_source_file IS NULL OR dwh_batch_id IS NULL), count(DISTINCT dwh_batch_id) FROM bronze.crm_prd_info      UNION ALL
SELECT 'crm_sales_details', count(*) FILTER (WHERE dwh_load_date IS NULL OR dwh_source_file IS NULL OR dwh_batch_id IS NULL), count(DISTINCT dwh_batch_id) FROM bronze.crm_sales_details UNION ALL
SELECT 'erp_cust_az12',     count(*) FILTER (WHERE dwh_load_date IS NULL OR dwh_source_file IS NULL OR dwh_batch_id IS NULL), count(DISTINCT dwh_batch_id) FROM bronze.erp_cust_az12     UNION ALL
SELECT 'erp_loc_a101',      count(*) FILTER (WHERE dwh_load_date IS NULL OR dwh_source_file IS NULL OR dwh_batch_id IS NULL), count(DISTINCT dwh_batch_id) FROM bronze.erp_loc_a101      UNION ALL
SELECT 'erp_px_cat_g1v2',   count(*) FILTER (WHERE dwh_load_date IS NULL OR dwh_source_file IS NULL OR dwh_batch_id IS NULL), count(DISTINCT dwh_batch_id) FROM bronze.erp_px_cat_g1v2;

-- ---------------------------------------------------------------------------
-- 5. Monitoreo: resultado del último lote de Bronze. Esperado: status = SUCCESS
-- ---------------------------------------------------------------------------
SELECT *
FROM audit.vw_batch_summary
WHERE layer_name = 'bronze'
ORDER BY batch_id DESC
LIMIT 1;

-- ---------------------------------------------------------------------------
-- 6. Muestra de datos de cada tabla
-- ---------------------------------------------------------------------------
SELECT * FROM bronze.crm_cust_info     LIMIT 5;
SELECT * FROM bronze.crm_prd_info      LIMIT 5;
SELECT * FROM bronze.crm_sales_details LIMIT 5;
SELECT * FROM bronze.erp_cust_az12     LIMIT 5;
SELECT * FROM bronze.erp_loc_a101      LIMIT 5;
SELECT * FROM bronze.erp_px_cat_g1v2   LIMIT 5;
