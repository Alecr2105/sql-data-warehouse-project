/*
=============================================================================
 Perfilado de datos: problemas de calidad detectados en Bronze
=============================================================================
 Propósito:
   Consultas exploratorias que identifican los problemas de calidad que la
   capa Silver debe resolver. Cada bloque indica el hallazgo y la regla
   de limpieza aplicada en silver.load_silver().
=============================================================================
*/

-- ===========================================================================
-- bronze.crm_cust_info
-- ===========================================================================
-- Hallazgo: cst_id duplicado o nulo  -> Regla: conservar el registro más reciente
SELECT cst_id, count(*)
FROM bronze.crm_cust_info
GROUP BY cst_id
HAVING count(*) > 1 OR cst_id IS NULL;

-- Hallazgo: espacios sobrantes en nombres -> Regla: TRIM
SELECT cst_firstname, cst_lastname
FROM bronze.crm_cust_info
WHERE cst_firstname <> trim(cst_firstname)
   OR cst_lastname  <> trim(cst_lastname);

-- Hallazgo: códigos abreviados -> Regla: M/F -> Male/Female, S/M -> Single/Married, vacío -> n/a
SELECT DISTINCT cst_gndr           FROM bronze.crm_cust_info;
SELECT DISTINCT cst_marital_status FROM bronze.crm_cust_info;

-- ===========================================================================
-- bronze.crm_prd_info
-- ===========================================================================
-- Hallazgo: prd_key combina categoría y producto -> Regla: derivar cat_id y prd_key
SELECT prd_key,
       replace(substring(prd_key FROM 1 FOR 5), '-', '_') AS cat_id,
       substring(prd_key FROM 7)                          AS prd_key_limpio
FROM bronze.crm_prd_info
LIMIT 10;

-- Hallazgo: costos nulos o negativos -> Regla: nulo -> 0
SELECT prd_id, prd_cost FROM bronze.crm_prd_info WHERE prd_cost IS NULL OR prd_cost < 0;

-- Hallazgo: códigos de línea con espacios -> Regla: M/R/S/T -> Mountain/Road/Other Sales/Touring
SELECT DISTINCT prd_line FROM bronze.crm_prd_info;

-- Hallazgo: fecha fin anterior a fecha inicio -> Regla: fin = siguiente inicio - 1 día
SELECT prd_key, prd_start_dt, prd_end_dt
FROM bronze.crm_prd_info
WHERE prd_end_dt < prd_start_dt;

-- ===========================================================================
-- bronze.crm_sales_details
-- ===========================================================================
-- Hallazgo: fechas como entero, con ceros o longitud inválida -> Regla: convertir a DATE o NULL
SELECT sls_ord_num, sls_order_dt
FROM bronze.crm_sales_details
WHERE sls_order_dt <= 0
   OR length(sls_order_dt::text) <> 8
   OR sls_order_dt > 20500101
   OR sls_order_dt < 19000101;

-- Hallazgo: fecha de pedido posterior a envío/vencimiento
SELECT * FROM bronze.crm_sales_details
WHERE sls_order_dt > sls_ship_dt OR sls_order_dt > sls_due_dt;

-- Hallazgo: ventas <> cantidad * precio, nulos o negativos
--   Regla: ventas = cantidad * |precio| ; precio = ventas / cantidad
SELECT sls_sales, sls_quantity, sls_price
FROM bronze.crm_sales_details
WHERE sls_sales <> sls_quantity * sls_price
   OR sls_sales IS NULL OR sls_quantity IS NULL OR sls_price IS NULL
   OR sls_sales <= 0    OR sls_quantity <= 0    OR sls_price <= 0
ORDER BY sls_sales, sls_quantity, sls_price;

-- Integración: toda venta referencia un producto y un cliente existentes en CRM
SELECT count(*) AS sales_without_product
FROM bronze.crm_sales_details s
WHERE NOT EXISTS (SELECT 1 FROM bronze.crm_prd_info p WHERE substring(p.prd_key FROM 7) = s.sls_prd_key);

SELECT count(*) AS sales_without_customer
FROM bronze.crm_sales_details s
WHERE NOT EXISTS (SELECT 1 FROM bronze.crm_cust_info c WHERE c.cst_id = s.sls_cust_id);

-- ===========================================================================
-- bronze.erp_cust_az12
-- ===========================================================================
-- Hallazgo: cid con prefijo 'NAS' que no coincide con cst_key -> Regla: quitar prefijo
SELECT cid FROM bronze.erp_cust_az12 WHERE cid LIKE 'NAS%' LIMIT 10;

-- Hallazgo: fechas de nacimiento futuras o muy antiguas -> Regla: futuras -> NULL
SELECT bdate FROM bronze.erp_cust_az12
WHERE bdate > current_date OR bdate < DATE '1924-01-01';

-- Hallazgo: género inconsistente (F, M, espacios, vacío) -> Regla: Female/Male/n/a
SELECT DISTINCT gen FROM bronze.erp_cust_az12;

-- ===========================================================================
-- bronze.erp_loc_a101
-- ===========================================================================
-- Hallazgo: cid con guion ('AW-00011000') -> Regla: quitar '-'
SELECT cid FROM bronze.erp_loc_a101 LIMIT 10;

-- Hallazgo: países no estandarizados (DE, US, USA, vacío) -> Regla: normalizar
SELECT DISTINCT cntry FROM bronze.erp_loc_a101 ORDER BY cntry;

-- ===========================================================================
-- bronze.erp_px_cat_g1v2
-- ===========================================================================
-- Hallazgo: espacios sobrantes / valores distintos -> sin problemas detectados
SELECT * FROM bronze.erp_px_cat_g1v2
WHERE cat <> trim(cat) OR subcat <> trim(subcat) OR maintenance <> trim(maintenance);
SELECT DISTINCT maintenance FROM bronze.erp_px_cat_g1v2;

-- Categorías de producto sin correspondencia en ERP (ej. CO_PE)
SELECT DISTINCT replace(substring(prd_key FROM 1 FOR 5), '-', '_') AS cat_id
FROM bronze.crm_prd_info
WHERE replace(substring(prd_key FROM 1 FOR 5), '-', '_') NOT IN (SELECT id FROM bronze.erp_px_cat_g1v2);
