/*
=============================================================================
 Seguridad: roles y permisos por capa
=============================================================================
 Propósito del script:
   Define permisos de acceso por cada capa de la arquitectura Medallion,
   según el público objetivo de cada una:

   | Rol            | bronze | silver | gold   | audit  | Procedimientos |
   |----------------|--------|--------|--------|--------|----------------|
   | dwh_engineer   | total  | total  | total  | total  | EXECUTE        |
   | dwh_analyst    |   -    | SELECT | SELECT | SELECT |       -        |
   | dwh_business   |   -    |   -    | SELECT |   -    |       -        |

   Son roles de grupo (NOLOGIN). Para dar acceso a una persona se crea un
   usuario con LOGIN y se le asigna el rol correspondiente (ver final).

 Ejecución (al final, cuando ya existen todos los objetos):
   psql -U postgres -d datawarehouse -f 03_scripts/security/roles_and_permissions.sql
=============================================================================
*/

-- ---------------------------------------------------------------------------
-- 1. Roles de grupo (los roles son globales al servidor: se crean si no existen)
-- ---------------------------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dwh_engineer') THEN
        CREATE ROLE dwh_engineer NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dwh_analyst') THEN
        CREATE ROLE dwh_analyst NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dwh_business') THEN
        CREATE ROLE dwh_business NOLOGIN;
    END IF;
END;
$$;

COMMENT ON ROLE dwh_engineer IS 'Ingenieros de datos: administran y ejecutan el ETL en todas las capas';
COMMENT ON ROLE dwh_analyst  IS 'Analistas de datos: consultan Silver, Gold y la auditoría';
COMMENT ON ROLE dwh_business IS 'Usuarios de negocio: consultan solo la capa Gold';

-- ---------------------------------------------------------------------------
-- 2. Base de datos: solo los roles del DW pueden conectarse
-- ---------------------------------------------------------------------------
REVOKE ALL ON DATABASE datawarehouse FROM PUBLIC;
GRANT CONNECT ON DATABASE datawarehouse TO dwh_engineer, dwh_analyst, dwh_business;

-- Los procedimientos de carga no deben ser ejecutables por cualquier usuario
REVOKE EXECUTE ON PROCEDURE bronze.load_bronze(TEXT) FROM PUBLIC;
REVOKE EXECUTE ON PROCEDURE silver.load_silver()      FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION  audit.assert_last_batch_ok(VARCHAR) FROM PUBLIC;

-- ---------------------------------------------------------------------------
-- 3. dwh_engineer: control total de todas las capas
-- ---------------------------------------------------------------------------
GRANT USAGE, CREATE ON SCHEMA bronze, silver, gold, audit TO dwh_engineer;
GRANT ALL ON ALL TABLES    IN SCHEMA bronze, silver, gold, audit TO dwh_engineer;
GRANT ALL ON ALL SEQUENCES IN SCHEMA audit TO dwh_engineer;
GRANT EXECUTE ON PROCEDURE bronze.load_bronze(TEXT) TO dwh_engineer;
GRANT EXECUTE ON PROCEDURE silver.load_silver()      TO dwh_engineer;
GRANT EXECUTE ON FUNCTION  audit.assert_last_batch_ok(VARCHAR) TO dwh_engineer;
-- COPY desde archivos del servidor (requerido por bronze.load_bronze)
GRANT pg_read_server_files TO dwh_engineer;

-- ---------------------------------------------------------------------------
-- 4. dwh_analyst: lectura de Silver, Gold y auditoría (sin acceso a Bronze)
-- ---------------------------------------------------------------------------
GRANT USAGE ON SCHEMA silver, gold, audit TO dwh_analyst;
GRANT SELECT ON ALL TABLES IN SCHEMA silver, gold, audit TO dwh_analyst;

-- ---------------------------------------------------------------------------
-- 5. dwh_business: lectura solo de la capa Gold
-- ---------------------------------------------------------------------------
GRANT USAGE ON SCHEMA gold TO dwh_business;
GRANT SELECT ON ALL TABLES IN SCHEMA gold TO dwh_business;

-- ---------------------------------------------------------------------------
-- 6. Privilegios por defecto: los objetos que se creen después heredan los permisos
-- ---------------------------------------------------------------------------
ALTER DEFAULT PRIVILEGES IN SCHEMA bronze, silver, gold, audit GRANT ALL    ON TABLES TO dwh_engineer;
ALTER DEFAULT PRIVILEGES IN SCHEMA silver, gold, audit         GRANT SELECT ON TABLES TO dwh_analyst;
ALTER DEFAULT PRIVILEGES IN SCHEMA gold                        GRANT SELECT ON TABLES TO dwh_business;

/*
-- ---------------------------------------------------------------------------
-- 7. Ejemplo: crear usuarios y asignarles un rol (ejecutar con contraseñas reales)
-- ---------------------------------------------------------------------------
CREATE ROLE usr_data_engineer LOGIN PASSWORD '********' IN ROLE dwh_engineer;
CREATE ROLE usr_data_analyst  LOGIN PASSWORD '********' IN ROLE dwh_analyst;
CREATE ROLE usr_bi_report     LOGIN PASSWORD '********' IN ROLE dwh_business;
*/
