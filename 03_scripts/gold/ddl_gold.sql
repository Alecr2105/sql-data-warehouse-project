/*
=============================================================================
 DDL: Capa Gold (vistas)
=============================================================================
 Propósito del script:
   Crea las vistas de la capa Gold. Esta capa representa el modelo final en
   estrella (Star Schema): dimensiones, tabla de hechos y un reporte agregado.
   Cada vista integra y transforma los datos de la capa Silver para producir
   un conjunto de datos limpio, enriquecido y listo para el negocio.

 Uso:
   psql -U postgres -d datawarehouse -f 03_scripts/gold/ddl_gold.sql
   SELECT * FROM gold.fact_sales LIMIT 10;
=============================================================================
*/

-- Las vistas se eliminan en orden inverso de dependencia
DROP VIEW IF EXISTS gold.report_sales_monthly;
DROP VIEW IF EXISTS gold.fact_sales;
DROP VIEW IF EXISTS gold.dim_products;
DROP VIEW IF EXISTS gold.dim_customers;

-- ===========================================================================
-- Dimensión: gold.dim_customers
--   Integra CRM (datos maestros) con ERP (fecha de nacimiento y país).
-- ===========================================================================
CREATE VIEW gold.dim_customers AS
SELECT
    row_number() OVER (ORDER BY ci.cst_id)  AS customer_key,     -- clave subrogada
    ci.cst_id                               AS customer_id,
    ci.cst_key                              AS customer_number,
    ci.cst_firstname                        AS first_name,
    ci.cst_lastname                         AS last_name,
    la.cntry                                AS country,
    ci.cst_marital_status                   AS marital_status,
    CASE WHEN ci.cst_gndr <> 'n/a' THEN ci.cst_gndr          -- CRM es la fuente principal
         ELSE coalesce(ca.gen, 'n/a')                         -- respaldo: ERP
    END                                     AS gender,
    ca.bdate                                AS birthdate,
    ci.cst_create_date                      AS create_date
FROM silver.crm_cust_info ci
LEFT JOIN silver.erp_cust_az12 ca
       ON ci.cst_key = ca.cid
LEFT JOIN silver.erp_loc_a101 la
       ON ci.cst_key = la.cid;

COMMENT ON VIEW gold.dim_customers IS 'Dimensión de clientes (CRM + ERP)';

-- ===========================================================================
-- Dimensión: gold.dim_products
--   Solo productos vigentes (sin fecha de fin), enriquecidos con la categoría ERP.
-- ===========================================================================
CREATE VIEW gold.dim_products AS
SELECT
    row_number() OVER (ORDER BY pn.prd_start_dt, pn.prd_key) AS product_key,   -- clave subrogada
    pn.prd_id                               AS product_id,
    pn.prd_key                              AS product_number,
    pn.prd_nm                               AS product_name,
    pn.cat_id                               AS category_id,
    pc.cat                                  AS category,
    pc.subcat                               AS subcategory,
    pc.maintenance                          AS maintenance,
    pn.prd_cost                             AS cost,
    pn.prd_line                             AS product_line,
    pn.prd_start_dt                         AS start_date
FROM silver.crm_prd_info pn
LEFT JOIN silver.erp_px_cat_g1v2 pc
       ON pn.cat_id = pc.id
WHERE pn.prd_end_dt IS NULL;   -- se excluyen versiones históricas

COMMENT ON VIEW gold.dim_products IS 'Dimensión de productos vigentes con su categoría';

-- ===========================================================================
-- Hechos: gold.fact_sales
--   Transacciones de venta enlazadas a las dimensiones por clave subrogada.
-- ===========================================================================
CREATE VIEW gold.fact_sales AS
SELECT
    sd.sls_ord_num      AS order_number,
    pr.product_key      AS product_key,
    cu.customer_key     AS customer_key,
    sd.sls_order_dt     AS order_date,
    sd.sls_ship_dt      AS shipping_date,
    sd.sls_due_dt       AS due_date,
    sd.sls_sales        AS sales_amount,
    sd.sls_quantity     AS quantity,
    sd.sls_price        AS price
FROM silver.crm_sales_details sd
LEFT JOIN gold.dim_products pr
       ON sd.sls_prd_key = pr.product_number
LEFT JOIN gold.dim_customers cu
       ON sd.sls_cust_id = cu.customer_id;

COMMENT ON VIEW gold.fact_sales IS 'Hechos de ventas (grano: línea de pedido)';

-- ===========================================================================
-- Reporte: gold.report_sales_monthly
--   Ventas agregadas por año y mes (ejemplo de vista analítica del enunciado).
-- ===========================================================================
CREATE VIEW gold.report_sales_monthly AS
SELECT
    extract(YEAR  FROM order_date)::INT     AS order_year,
    extract(MONTH FROM order_date)::INT     AS order_month,
    count(DISTINCT order_number)            AS total_orders,
    count(DISTINCT customer_key)            AS total_customers,
    sum(quantity)                           AS total_quantity,
    sum(sales_amount)                       AS total_sales
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY extract(YEAR FROM order_date), extract(MONTH FROM order_date)
ORDER BY order_year, order_month;

COMMENT ON VIEW gold.report_sales_monthly IS 'Ventas totales por año y mes';
