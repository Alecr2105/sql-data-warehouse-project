/*
=============================================================================
 Validaciones de calidad: capa Silver
=============================================================================
 Propósito:
   Verificar la consistencia, exactitud y estandarización de los datos
   después de ejecutar CALL silver.load_silver().

 Resultado esperado:
   Todas las consultas marcadas con "Esperado: sin resultados" deben devolver
   0 filas. Las consultas DISTINCT muestran los valores estandarizados.
=============================================================================
*/

-- ===========================================================================
-- silver.crm_cust_info
-- ===========================================================================
-- Claves primarias nulas o duplicadas. Esperado: sin resultados
SELECT cst_id, count(*)
FROM silver.crm_cust_info
GROUP BY cst_id
HAVING count(*) > 1 OR cst_id IS NULL;

-- Espacios sobrantes. Esperado: sin resultados
SELECT cst_key FROM silver.crm_cust_info
WHERE cst_key <> trim(cst_key)
   OR cst_firstname <> trim(cst_firstname)
   OR cst_lastname  <> trim(cst_lastname);

-- Estandarización. Esperado: Single / Married / n/a y Female / Male / n/a
SELECT DISTINCT cst_marital_status FROM silver.crm_cust_info;
SELECT DISTINCT cst_gndr           FROM silver.crm_cust_info;

-- ===========================================================================
-- silver.crm_prd_info
-- ===========================================================================
-- Claves primarias nulas o duplicadas. Esperado: sin resultados
SELECT prd_id, count(*)
FROM silver.crm_prd_info
GROUP BY prd_id
HAVING count(*) > 1 OR prd_id IS NULL;

-- Espacios sobrantes en el nombre. Esperado: sin resultados
SELECT prd_nm FROM silver.crm_prd_info WHERE prd_nm <> trim(prd_nm);

-- Costos nulos o negativos. Esperado: sin resultados
SELECT prd_cost FROM silver.crm_prd_info WHERE prd_cost IS NULL OR prd_cost < 0;

-- Estandarización. Esperado: Mountain / Road / Other Sales / Touring / n/a
SELECT DISTINCT prd_line FROM silver.crm_prd_info;

-- Fecha fin anterior a fecha inicio. Esperado: sin resultados
SELECT * FROM silver.crm_prd_info WHERE prd_end_dt < prd_start_dt;

-- ===========================================================================
-- silver.crm_sales_details
-- ===========================================================================
-- Orden de fechas inválido. Esperado: sin resultados
SELECT * FROM silver.crm_sales_details
WHERE sls_order_dt > sls_ship_dt
   OR sls_order_dt > sls_due_dt;

-- Consistencia: ventas = cantidad * precio. Esperado: sin resultados
SELECT DISTINCT sls_sales, sls_quantity, sls_price
FROM silver.crm_sales_details
WHERE sls_sales <> sls_quantity * sls_price
   OR sls_sales IS NULL OR sls_quantity IS NULL OR sls_price IS NULL
   OR sls_sales <= 0    OR sls_quantity <= 0    OR sls_price <= 0;

-- Fechas de pedido descartadas por inválidas (informativo)
SELECT count(*) AS orders_without_date FROM silver.crm_sales_details WHERE sls_order_dt IS NULL;

-- ===========================================================================
-- silver.erp_cust_az12
-- ===========================================================================
-- Prefijo 'NAS' eliminado. Esperado: sin resultados
SELECT cid FROM silver.erp_cust_az12 WHERE cid LIKE 'NAS%';

-- Fechas de nacimiento futuras. Esperado: sin resultados
SELECT bdate FROM silver.erp_cust_az12 WHERE bdate > current_date;

-- Estandarización. Esperado: Female / Male / n/a
SELECT DISTINCT gen FROM silver.erp_cust_az12;

-- ===========================================================================
-- silver.erp_loc_a101
-- ===========================================================================
-- Guiones eliminados de la clave. Esperado: sin resultados
SELECT cid FROM silver.erp_loc_a101 WHERE cid LIKE '%-%';

-- Estandarización de países. Esperado: nombres completos sin DE / US / USA
SELECT DISTINCT cntry FROM silver.erp_loc_a101 ORDER BY cntry;

-- ===========================================================================
-- Integración CRM <-> ERP
-- ===========================================================================
-- Clientes ERP (az12) sin correspondencia en CRM. Esperado: sin resultados
SELECT a.cid FROM silver.erp_cust_az12 a
WHERE NOT EXISTS (SELECT 1 FROM silver.crm_cust_info c WHERE c.cst_key = a.cid);

-- Ubicaciones ERP sin correspondencia en CRM. Esperado: sin resultados
SELECT l.cid FROM silver.erp_loc_a101 l
WHERE NOT EXISTS (SELECT 1 FROM silver.crm_cust_info c WHERE c.cst_key = l.cid);

-- Ventas cuyo producto no existe en el catálogo. Esperado: sin resultados
SELECT s.sls_prd_key FROM silver.crm_sales_details s
WHERE NOT EXISTS (SELECT 1 FROM silver.crm_prd_info p WHERE p.prd_key = s.sls_prd_key);

-- ===========================================================================
-- Auditoría de la carga (trazabilidad, monitoreo y calidad)
-- ===========================================================================
-- Toda fila de Silver pertenece al último lote. Esperado: sin resultados
SELECT 'crm_cust_info' AS table_name, count(*) AS rows_without_batch FROM silver.crm_cust_info     WHERE dwh_batch_id IS NULL HAVING count(*) > 0 UNION ALL
SELECT 'crm_prd_info',                count(*)                       FROM silver.crm_prd_info      WHERE dwh_batch_id IS NULL HAVING count(*) > 0 UNION ALL
SELECT 'crm_sales_details',           count(*)                       FROM silver.crm_sales_details WHERE dwh_batch_id IS NULL HAVING count(*) > 0 UNION ALL
SELECT 'erp_cust_az12',               count(*)                       FROM silver.erp_cust_az12     WHERE dwh_batch_id IS NULL HAVING count(*) > 0 UNION ALL
SELECT 'erp_loc_a101',                count(*)                       FROM silver.erp_loc_a101      WHERE dwh_batch_id IS NULL HAVING count(*) > 0 UNION ALL
SELECT 'erp_px_cat_g1v2',             count(*)                       FROM silver.erp_px_cat_g1v2   WHERE dwh_batch_id IS NULL HAVING count(*) > 0;

-- Resultado del último lote de Silver. Esperado: status = SUCCESS
SELECT *
FROM audit.vw_batch_summary
WHERE layer_name = 'silver'
ORDER BY batch_id DESC
LIMIT 1;

-- Conciliación: filas Bronze = filas Silver + rechazadas (clientes)
-- Esperado: row_difference = 0
SELECT (SELECT count(*) FROM bronze.crm_cust_info)
     - (SELECT count(*) FROM silver.crm_cust_info)
     - (SELECT count(*) FROM audit.rejected_records
        WHERE batch_id = (SELECT max(dwh_batch_id) FROM silver.crm_cust_info)
          AND table_name = 'silver.crm_cust_info'
          AND action_taken = 'REJECTED') AS row_difference;

-- Resumen de registros rechazados y corregidos del último lote (informativo)
SELECT table_name, action_taken, reason, count(*) AS records
FROM audit.rejected_records
WHERE batch_id = (SELECT max(dwh_batch_id) FROM silver.crm_cust_info)
GROUP BY table_name, action_taken, reason
ORDER BY table_name, action_taken, reason;
