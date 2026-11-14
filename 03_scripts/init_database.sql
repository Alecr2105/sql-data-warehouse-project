/*
=============================================================================
 Crear base de datos y esquemas
=============================================================================
 Propósito del script:
   Crea la base de datos 'datawarehouse' (eliminándola primero si existe) y
   los tres esquemas de la arquitectura Medallion: bronze, silver y gold.

 ADVERTENCIA:
   Ejecutar este script ELIMINA por completo la base de datos 'datawarehouse'
   y todos sus datos. Verifique que tiene respaldos antes de ejecutarlo.

 Ejecución (psql, conectado como superusuario a la BD 'postgres'):
   psql -U postgres -d postgres -f 03_scripts/init_database.sql
=============================================================================
*/

-- Cerrar conexiones abiertas a la base de datos antes de eliminarla
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE datname = 'datawarehouse'
  AND pid <> pg_backend_pid();

DROP DATABASE IF EXISTS datawarehouse;

CREATE DATABASE datawarehouse
    WITH ENCODING = 'UTF8'
         TEMPLATE = template0;

-- Conectarse a la nueva base de datos (meta-comando de psql)
\connect datawarehouse

-- Esquemas de la arquitectura Medallion
CREATE SCHEMA IF NOT EXISTS bronze;   -- Datos originales
CREATE SCHEMA IF NOT EXISTS silver;   -- Datos depurados
CREATE SCHEMA IF NOT EXISTS gold;     -- Datos analíticos

COMMENT ON SCHEMA bronze IS 'Capa Bronze: datos originales tal como se reciben de CRM y ERP';
COMMENT ON SCHEMA silver IS 'Capa Silver: datos limpios, estandarizados y enriquecidos';
COMMENT ON SCHEMA gold   IS 'Capa Gold: modelo en estrella listo para análisis';
