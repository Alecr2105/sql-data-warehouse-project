/*
=============================================================================
 Validaciones de calidad: capa Gold
=============================================================================
 Propósito:
   Verificar la integridad, consistencia y exactitud del modelo en estrella:
   - Unicidad de las claves subrogadas en las dimensiones
   - Integridad referencial entre la tabla de hechos y las dimensiones
   - Conciliación de totales entre Silver y Gold

 Resultado esperado: las consultas marcadas devuelven 0 filas.
=============================================================================
*/

-- ===========================================================================
-- gold.dim_customers
-- ===========================================================================
-- Unicidad de customer_key. Esperado: sin resultados
SELECT customer_key, count(*)
FROM gold.dim_customers
GROUP BY customer_key
HAVING count(*) > 1;

-- Unicidad de la clave de negocio. Esperado: sin resultados
SELECT customer_id, count(*)
FROM gold.dim_customers
GROUP BY customer_id
HAVING count(*) > 1;

-- Integración del género (CRM con respaldo ERP). Valores: Female / Male / n/a
SELECT DISTINCT gender FROM gold.dim_customers;

-- ===========================================================================
-- gold.dim_products
-- ===========================================================================
-- Unicidad de product_key. Esperado: sin resultados
SELECT product_key, count(*)
FROM gold.dim_products
GROUP BY product_key
HAVING count(*) > 1;

-- Un solo registro vigente por producto. Esperado: sin resultados
SELECT product_number, count(*)
FROM gold.dim_products
GROUP BY product_number
HAVING count(*) > 1;

-- ===========================================================================
-- gold.fact_sales
-- ===========================================================================
-- Integridad referencial hechos -> dimensiones. Esperado: sin resultados
SELECT f.*
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c ON c.customer_key = f.customer_key
LEFT JOIN gold.dim_products  p ON p.product_key  = f.product_key
WHERE c.customer_key IS NULL
   OR p.product_key  IS NULL;

-- Conciliación de filas y montos Silver vs Gold. Esperado: diferencias en 0
SELECT
    (SELECT count(*)          FROM silver.crm_sales_details) - (SELECT count(*)          FROM gold.fact_sales) AS row_difference,
    (SELECT sum(sls_sales)    FROM silver.crm_sales_details) - (SELECT sum(sales_amount) FROM gold.fact_sales) AS sales_difference;

-- ===========================================================================
-- gold.report_sales_monthly
-- ===========================================================================
-- El reporte cuadra con la tabla de hechos (excluye pedidos sin fecha). Esperado: 0
SELECT
    (SELECT sum(sales_amount) FROM gold.fact_sales WHERE order_date IS NOT NULL)
  - (SELECT sum(total_sales)  FROM gold.report_sales_monthly) AS sales_difference;

-- Muestra del reporte
SELECT * FROM gold.report_sales_monthly;
