/*
=============================================================================
 Ejecución del ETL (proceso recurrente)
=============================================================================
 Propósito:
   Ejecuta la carga completa Bronze -> Silver sobre una base de datos ya
   creada. Las vistas Gold se actualizan solas porque leen de Silver.
   Es el script que se programa para ejecutarse automáticamente
   (ver 00_setup/run_etl.ps1). NO elimina ni recrea la base de datos.

   Si una capa falla, audit.assert_last_batch_ok() detiene la ejecución,
   así Silver nunca se carga a partir de un Bronze incompleto.

 Uso:
   psql -U postgres -d datawarehouse -v dataset_path="C:/datasets" -f 03_scripts/run_etl.sql
=============================================================================
*/
\set ON_ERROR_STOP on

\echo '>> Carga Bronze'
CALL bronze.load_bronze(:'dataset_path');
SELECT audit.assert_last_batch_ok('bronze') AS bronze_batch_id;

\echo '>> Carga Silver'
CALL silver.load_silver();
SELECT audit.assert_last_batch_ok('silver') AS silver_batch_id;

\echo '>> Resumen de los lotes ejecutados'
SELECT *
FROM audit.vw_batch_summary
ORDER BY batch_id DESC
LIMIT 2;
