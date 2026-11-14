/*
=============================================================================
 DDL: Capa Silver
=============================================================================
 Propósito del script:
   Crea las tablas del esquema 'silver', eliminándolas primero si existen.
   Mantiene la nomenclatura de origen (<sistema>_<entidad>) con tipos de datos
   corregidos, columnas derivadas y las columnas técnicas dwh_create_date
   (fecha de carga) y dwh_batch_id (lote de ejecución).

 Ejecución:
   psql -U postgres -d datawarehouse -f 03_scripts/silver/ddl_silver.sql
=============================================================================
*/

-- ---------------------------------------------------------------------------
-- CRM
-- ---------------------------------------------------------------------------
DROP TABLE IF EXISTS silver.crm_cust_info;
CREATE TABLE silver.crm_cust_info (
    cst_id              INT,
    cst_key             VARCHAR(50),
    cst_firstname       VARCHAR(50),
    cst_lastname        VARCHAR(50),
    cst_marital_status  VARCHAR(50),
    cst_gndr            VARCHAR(50),
    cst_create_date     DATE,
    dwh_create_date     TIMESTAMP DEFAULT now(),
    dwh_batch_id    BIGINT                     -- lote de ejecución (audit.load_log)
);

DROP TABLE IF EXISTS silver.crm_prd_info;
CREATE TABLE silver.crm_prd_info (
    prd_id          INT,
    cat_id          VARCHAR(50),     -- derivada de prd_key
    prd_key         VARCHAR(50),
    prd_nm          VARCHAR(50),
    prd_cost        INT,
    prd_line        VARCHAR(50),
    prd_start_dt    DATE,
    prd_end_dt      DATE,
    dwh_create_date TIMESTAMP DEFAULT now(),
    dwh_batch_id    BIGINT                     -- lote de ejecución (audit.load_log)
);

DROP TABLE IF EXISTS silver.crm_sales_details;
CREATE TABLE silver.crm_sales_details (
    sls_ord_num     VARCHAR(50),
    sls_prd_key     VARCHAR(50),
    sls_cust_id     INT,
    sls_order_dt    DATE,
    sls_ship_dt     DATE,
    sls_due_dt      DATE,
    sls_sales       INT,
    sls_quantity    INT,
    sls_price       INT,
    dwh_create_date TIMESTAMP DEFAULT now(),
    dwh_batch_id    BIGINT                     -- lote de ejecución (audit.load_log)
);

-- ---------------------------------------------------------------------------
-- ERP
-- ---------------------------------------------------------------------------
DROP TABLE IF EXISTS silver.erp_cust_az12;
CREATE TABLE silver.erp_cust_az12 (
    cid             VARCHAR(50),
    bdate           DATE,
    gen             VARCHAR(50),
    dwh_create_date TIMESTAMP DEFAULT now(),
    dwh_batch_id    BIGINT                     -- lote de ejecución (audit.load_log)
);

DROP TABLE IF EXISTS silver.erp_loc_a101;
CREATE TABLE silver.erp_loc_a101 (
    cid             VARCHAR(50),
    cntry           VARCHAR(50),
    dwh_create_date TIMESTAMP DEFAULT now(),
    dwh_batch_id    BIGINT                     -- lote de ejecución (audit.load_log)
);

DROP TABLE IF EXISTS silver.erp_px_cat_g1v2;
CREATE TABLE silver.erp_px_cat_g1v2 (
    id              VARCHAR(50),
    cat             VARCHAR(50),
    subcat          VARCHAR(50),
    maintenance     VARCHAR(50),
    dwh_create_date TIMESTAMP DEFAULT now(),
    dwh_batch_id    BIGINT                     -- lote de ejecución (audit.load_log)
);
