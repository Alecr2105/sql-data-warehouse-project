/*
=============================================================================
 Script maestro: construye el data warehouse completo desde cero
=============================================================================
 ADVERTENCIA: elimina y recrea la base de datos 'datawarehouse'.
 Para las cargas recurrentes use 03_scripts/run_etl.sql.

 Ejecutar desde la raíz del repositorio:
   psql -U postgres -d postgres -v dataset_path="C:/datasets" -f 00_setup/run_all.sql
=============================================================================
*/
\set ON_ERROR_STOP on

\echo '>> 1. Base de datos y esquemas'
\i 03_scripts/init_database.sql

\echo '>> 2. Auditoría (trazabilidad, monitoreo y calidad)'
\i 03_scripts/audit/ddl_audit.sql

\echo '>> 3. Capa Bronze'
\i 03_scripts/bronze/ddl_bronze.sql
\i 03_scripts/bronze/proc_load_bronze.sql
CALL bronze.load_bronze(:'dataset_path');
SELECT audit.assert_last_batch_ok('bronze') AS bronze_batch_id;

\echo '>> 4. Capa Silver'
\i 03_scripts/silver/ddl_silver.sql
\i 03_scripts/silver/proc_load_silver.sql
CALL silver.load_silver();
SELECT audit.assert_last_batch_ok('silver') AS silver_batch_id;

\echo '>> 5. Capa Gold'
\i 03_scripts/gold/ddl_gold.sql

\echo '>> 6. Seguridad por capa'
\i 03_scripts/security/roles_and_permissions.sql

\echo '>> Data warehouse construido. Ejecute los scripts de 04_tests para validar.'
SELECT * FROM audit.vw_batch_summary ORDER BY batch_id;
