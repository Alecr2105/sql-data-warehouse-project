/*
=============================================================================
 DDL: Capa Bronze
=============================================================================
 Propósito del script:
   Crea las tablas del esquema 'bronze', eliminándolas primero si existen.
   La estructura respeta los archivos de origen (mismas columnas y nombres,
   tabla = <sistema_origen>_<entidad>), sin transformaciones.
   Las fechas de ventas se conservan como enteros (yyyymmdd) tal como llegan.

   Columnas técnicas de trazabilidad (prefijo dwh_), sin alterar los datos:
     dwh_load_date    fecha y hora de la extracción
     dwh_source_file  archivo de origen del registro (identifica el sistema)
     dwh_batch_id     lote de ejecución (ver audit.load_log)

 Ejecución:
   psql -U postgres -d datawarehouse -f 03_scripts/bronze/ddl_bronze.sql
=============================================================================
*/

-- ---------------------------------------------------------------------------
-- CRM
-- ---------------------------------------------------------------------------
DROP TABLE IF EXISTS bronze.crm_cust_info;
CREATE TABLE bronze.crm_cust_info (
    cst_id              INT,
    cst_key             VARCHAR(50),
    cst_firstname       VARCHAR(50),
    cst_lastname        VARCHAR(50),
    cst_marital_status  VARCHAR(50),
    cst_gndr            VARCHAR(50),
    cst_create_date     DATE,
    dwh_load_date       TIMESTAMP    DEFAULT now(),   -- fecha y hora de extracción
    dwh_source_file     VARCHAR(255),                 -- archivo de origen
    dwh_batch_id        BIGINT                        -- lote de ejecución
);

DROP TABLE IF EXISTS bronze.crm_prd_info;
CREATE TABLE bronze.crm_prd_info (
    prd_id          INT,
    prd_key         VARCHAR(50),
    prd_nm          VARCHAR(50),
    prd_cost        INT,
    prd_line        VARCHAR(50),
    prd_start_dt    TIMESTAMP,
    prd_end_dt      TIMESTAMP,
    dwh_load_date       TIMESTAMP    DEFAULT now(),   -- fecha y hora de extracción
    dwh_source_file     VARCHAR(255),                 -- archivo de origen
    dwh_batch_id        BIGINT                        -- lote de ejecución
);

DROP TABLE IF EXISTS bronze.crm_sales_details;
CREATE TABLE bronze.crm_sales_details (
    sls_ord_num     VARCHAR(50),
    sls_prd_key     VARCHAR(50),
    sls_cust_id     INT,
    sls_order_dt    INT,
    sls_ship_dt     INT,
    sls_due_dt      INT,
    sls_sales       INT,
    sls_quantity    INT,
    sls_price       INT,
    dwh_load_date       TIMESTAMP    DEFAULT now(),   -- fecha y hora de extracción
    dwh_source_file     VARCHAR(255),                 -- archivo de origen
    dwh_batch_id        BIGINT                        -- lote de ejecución
);

-- ---------------------------------------------------------------------------
-- ERP
-- ---------------------------------------------------------------------------
DROP TABLE IF EXISTS bronze.erp_cust_az12;
CREATE TABLE bronze.erp_cust_az12 (
    cid     VARCHAR(50),
    bdate   DATE,
    gen     VARCHAR(50),
    dwh_load_date       TIMESTAMP    DEFAULT now(),   -- fecha y hora de extracción
    dwh_source_file     VARCHAR(255),                 -- archivo de origen
    dwh_batch_id        BIGINT                        -- lote de ejecución
);

DROP TABLE IF EXISTS bronze.erp_loc_a101;
CREATE TABLE bronze.erp_loc_a101 (
    cid     VARCHAR(50),
    cntry   VARCHAR(50),
    dwh_load_date       TIMESTAMP    DEFAULT now(),   -- fecha y hora de extracción
    dwh_source_file     VARCHAR(255),                 -- archivo de origen
    dwh_batch_id        BIGINT                        -- lote de ejecución
);

DROP TABLE IF EXISTS bronze.erp_px_cat_g1v2;
CREATE TABLE bronze.erp_px_cat_g1v2 (
    id           VARCHAR(50),
    cat          VARCHAR(50),
    subcat       VARCHAR(50),
    maintenance  VARCHAR(50),
    dwh_load_date       TIMESTAMP    DEFAULT now(),   -- fecha y hora de extracción
    dwh_source_file     VARCHAR(255),                 -- archivo de origen
    dwh_batch_id        BIGINT                        -- lote de ejecución
);
