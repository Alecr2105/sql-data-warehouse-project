# Operación y buenas prácticas

Cómo se aplican en este proyecto las recomendaciones de operación de la arquitectura
Medallion. El equivalente en PostgreSQL de las herramientas de SQL Server es:

| SQL Server | Este proyecto (PostgreSQL) |
|---|---|
| SSIS (extracción, transformación y carga) | Procedimientos `bronze.load_bronze` y `silver.load_silver` |
| SQL Server Agent (calendarización) | Programador de tareas de Windows + `00_setup/run_etl.ps1` |
| SSMS (administración y desarrollo) | pgAdmin 4 / `psql` |
| Power BI (visualización) | Power BI u otra herramienta BI conectada a las vistas `gold` |

## Recomendaciones aplicadas

| Aspecto | Recomendación | Implementación |
|---|---|---|
| **Trazabilidad** | Registrar fecha de carga, origen y lote de ejecución. | Bronze: `dwh_load_date`, `dwh_source_file`, `dwh_batch_id` en cada fila. Silver: `dwh_create_date`, `dwh_batch_id`. Lotes numerados con `audit.batch_id_seq`. |
| **Calidad** | Establecer reglas de validación de datos. | Reglas en `silver.load_silver`; validaciones en `04_tests/` (Bronze, Silver y Gold). |
| **Duplicados** | Mecanismos para identificar registros repetidos. | Clientes deduplicados por `cst_id` (se conserva el más reciente); los descartados quedan en `audit.rejected_records`. |
| **Seguridad** | Definir permisos de acceso por cada capa. | Roles `dwh_engineer`, `dwh_analyst`, `dwh_business` en `03_scripts/security/roles_and_permissions.sql`. |
| **Automatización** | Programar los procesos. | `03_scripts/run_etl.sql` + `00_setup/run_etl.ps1` en el Programador de tareas. |
| **Monitoreo** | Registrar errores, duración y cantidad de registros procesados. | `audit.load_log` (por tabla) y `audit.vw_batch_summary` (por lote). Log de texto por ejecución en `logs/`. |
| **Recuperación** | Mecanismos de respaldo y reprocesamiento. | `00_setup/backup_datawarehouse.ps1` (pg_dump con retención). Reproceso: la carga es completa e idempotente; ante un fallo el lote se revierte y basta con volver a ejecutar. |

## Esquema `audit`

### `audit.load_log` — monitoreo

Una fila por tabla procesada en cada lote (o una fila `FAILED` si el lote falla).

| Columna | Descripción |
|---|---|
| `log_id` | Identificador del registro. |
| `batch_id` | Lote de ejecución (uno por llamada a un procedimiento de carga). |
| `layer_name` | Capa: `bronze` o `silver`. |
| `table_name` | Tabla cargada (o la que estaba en proceso cuando ocurrió el error). |
| `source_name` | Archivo CSV o tabla de origen. |
| `status` | `SUCCESS` o `FAILED`. |
| `rows_loaded` / `rows_rejected` | Registros cargados y rechazados. |
| `start_time` / `end_time` / `duration_seconds` | Tiempos de ejecución. |
| `error_message` | Código y mensaje del error. |

### `audit.rejected_records` — calidad

Registros que una regla de calidad **rechazó** (no se cargan) o **corrigió** (se cargan con
el valor corregido). Guarda el registro original completo en `record_data` (JSONB).

Resultado de la carga actual:

| Tabla | Acción | Motivo | Registros |
|---|---|---|---:|
| `silver.crm_cust_info` | REJECTED | Clave primaria `cst_id` nula | 4 |
| `silver.crm_cust_info` | REJECTED | `cst_id` duplicado (se conserva el más reciente) | 6 |
| `silver.crm_prd_info` | CORRECTED | Costo nulo reemplazado por 0 | 2 |
| `silver.crm_prd_info` | CORRECTED | Fecha fin anterior a fecha inicio | 200 |
| `silver.crm_sales_details` | CORRECTED | Fecha de pedido inválida → NULL | 19 |
| `silver.crm_sales_details` | CORRECTED | Monto inconsistente → cantidad × precio | 23 |
| `silver.crm_sales_details` | CORRECTED | Precio inválido → ventas / cantidad | 12 |
| `silver.erp_cust_az12` | CORRECTED | Fecha de nacimiento futura → NULL | 16 |
| `silver.erp_loc_a101` | CORRECTED | País vacío → `n/a` | 337 |

## Manejo de errores

1. Cada procedimiento trabaja dentro de un bloque transaccional.
2. Si una tabla falla, **se revierte todo el lote**: las tablas conservan los datos de la
   carga anterior, nunca quedan a medias.
3. El error se registra en `audit.load_log` con estado `FAILED`.
4. `audit.assert_last_batch_ok('<capa>')` detiene `run_etl.sql` y `run_all.sql`, de modo
   que Silver nunca se carga desde un Bronze incompleto.
5. `run_etl.ps1` termina con código distinto de 0, lo que el Programador de tareas
   muestra como ejecución fallida.

## Consultas de monitoreo

```sql
-- Últimas ejecuciones
SELECT * FROM audit.vw_batch_summary ORDER BY batch_id DESC LIMIT 10;

-- Errores registrados
SELECT batch_id, layer_name, table_name, start_time, error_message
FROM audit.load_log
WHERE status = 'FAILED'
ORDER BY log_id DESC;

-- Registros rechazados en el último lote de Silver
SELECT record_key, reason, record_data
FROM audit.rejected_records
WHERE action_taken = 'REJECTED'
  AND batch_id = (SELECT max(batch_id) FROM audit.load_log WHERE layer_name = 'silver');
```
