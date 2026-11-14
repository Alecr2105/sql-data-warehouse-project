/*
=============================================================================
 DDL: Esquema de auditoría (operación del ETL)
=============================================================================
 Propósito del script:
   Crea el esquema 'audit', que da soporte a las buenas prácticas de operación
   de la arquitectura Medallion:

   | Aspecto        | Objeto                       |
   |----------------|------------------------------|
   | Trazabilidad   | audit.batch_id_seq (lote)    |
   | Monitoreo      | audit.load_log               |
   | Calidad        | audit.rejected_records       |

   Los procedimientos load_bronze y load_silver escriben en estas tablas.

 Ejecución (después de init_database.sql):
   psql -U postgres -d datawarehouse -f 03_scripts/audit/ddl_audit.sql
=============================================================================
*/

CREATE SCHEMA IF NOT EXISTS audit;
COMMENT ON SCHEMA audit IS 'Auditoría del ETL: lotes, registro de cargas y registros rechazados';

-- ---------------------------------------------------------------------------
-- Lote de ejecución: cada llamada a un procedimiento de carga obtiene un id
-- ---------------------------------------------------------------------------
CREATE SEQUENCE IF NOT EXISTS audit.batch_id_seq;

-- La vista de resumen depende de load_log: se elimina primero
DROP VIEW IF EXISTS audit.vw_batch_summary;

-- ---------------------------------------------------------------------------
-- Monitoreo: una fila por tabla procesada (o por fallo) en cada lote
-- ---------------------------------------------------------------------------
DROP TABLE IF EXISTS audit.load_log;
CREATE TABLE audit.load_log (
    log_id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    batch_id          BIGINT       NOT NULL,
    layer_name        VARCHAR(20)  NOT NULL,            -- bronze | silver
    table_name        VARCHAR(100),
    source_name       VARCHAR(255),                     -- archivo o tabla de origen
    status            VARCHAR(20)  NOT NULL,            -- SUCCESS | FAILED
    rows_loaded       BIGINT,
    rows_rejected     BIGINT,
    start_time        TIMESTAMP    NOT NULL,
    end_time          TIMESTAMP    NOT NULL DEFAULT clock_timestamp(),
    duration_seconds  NUMERIC(10,3),
    error_message     TEXT,
    CONSTRAINT chk_load_log_status CHECK (status IN ('SUCCESS', 'FAILED'))
);

CREATE INDEX idx_load_log_batch ON audit.load_log (batch_id);

COMMENT ON TABLE audit.load_log IS 'Registro de ejecución del ETL: filas, duración y errores por tabla y lote';

-- ---------------------------------------------------------------------------
-- Calidad: registros descartados o corregidos durante la limpieza
-- ---------------------------------------------------------------------------
DROP TABLE IF EXISTS audit.rejected_records;
CREATE TABLE audit.rejected_records (
    rejected_id   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    batch_id      BIGINT       NOT NULL,
    layer_name    VARCHAR(20)  NOT NULL,
    table_name    VARCHAR(100) NOT NULL,
    record_key    VARCHAR(100),                       -- clave de negocio del registro
    action_taken  VARCHAR(20)  NOT NULL,              -- REJECTED | CORRECTED
    reason        VARCHAR(255) NOT NULL,
    record_data   JSONB,                              -- registro original completo
    dwh_create_date TIMESTAMP  NOT NULL DEFAULT now(),
    CONSTRAINT chk_rejected_action CHECK (action_taken IN ('REJECTED', 'CORRECTED'))
);

CREATE INDEX idx_rejected_records_batch ON audit.rejected_records (batch_id);

COMMENT ON TABLE audit.rejected_records IS 'Registros rechazados o corregidos por las reglas de calidad';

-- ---------------------------------------------------------------------------
-- Verificación del último lote de una capa (usada por los scripts de ejecución)
--   Lanza un error si el último lote de la capa falló, para detener el flujo.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION audit.assert_last_batch_ok(p_layer_name VARCHAR)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    v_batch_id  BIGINT;
    v_error     TEXT;
BEGIN
    SELECT max(batch_id) INTO v_batch_id
    FROM audit.load_log
    WHERE layer_name = p_layer_name;

    IF v_batch_id IS NULL THEN
        RAISE EXCEPTION 'No existe ninguna carga registrada para la capa %', p_layer_name;
    END IF;

    SELECT error_message INTO v_error
    FROM audit.load_log
    WHERE batch_id = v_batch_id AND status = 'FAILED'
    LIMIT 1;

    IF FOUND THEN
        RAISE EXCEPTION 'El lote % de la capa % falló: %', v_batch_id, p_layer_name, v_error;
    END IF;

    RETURN v_batch_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- Vista de monitoreo: resumen por lote
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW audit.vw_batch_summary AS
SELECT
    batch_id,
    layer_name,
    min(start_time)                                  AS batch_start,
    max(end_time)                                    AS batch_end,
    round(extract(epoch FROM max(end_time) - min(start_time))::numeric, 3) AS duration_seconds,
    count(*) FILTER (WHERE table_name IS NOT NULL)   AS tables_processed,
    sum(rows_loaded)                                 AS rows_loaded,
    sum(rows_rejected)                               AS rows_rejected,
    CASE WHEN bool_or(status = 'FAILED') THEN 'FAILED' ELSE 'SUCCESS' END AS status
FROM audit.load_log
GROUP BY batch_id, layer_name;

COMMENT ON VIEW audit.vw_batch_summary IS 'Resumen de cada ejecución del ETL';
