# Guía de configuración

## Requisitos

- **PostgreSQL 14 o superior** (probado con PostgreSQL 18) y el cliente `psql`.
- Usuario con permisos de superusuario (por ejemplo `postgres`) o con el rol
  `pg_read_server_files`, necesario para que `COPY` lea los CSV desde el servidor.
- Opcional: pgAdmin 4 o DBeaver para explorar los datos.

> En Windows, agregue `C:\Program Files\PostgreSQL\<versión>\bin` a la variable `PATH`
> para poder usar `psql` desde la terminal. Si su servidor no usa el puerto 5432,
> agregue `-p <puerto>` a todos los comandos.

### Ubicación de los datasets

`COPY` es ejecutado por el **servicio** de PostgreSQL, que normalmente no puede leer
carpetas de usuario como Escritorio u OneDrive. Copie `01_datasets` a una ruta accesible:

```powershell
Copy-Item -Recurse .\01_datasets C:\datasets
```

### Credenciales (sin escribir contraseñas en los scripts)

Cree `%APPDATA%\postgresql\pgpass.conf` con una línea por conexión:

```
localhost:5432:*:postgres:<contraseña>
```

## Construcción inicial

Ejecute los comandos desde la raíz del repositorio.

| Paso | Script | Qué hace |
|---|---|---|
| 1 | `03_scripts/init_database.sql` | Crea la BD `datawarehouse` y los esquemas `bronze`, `silver`, `gold`. |
| 2 | `03_scripts/audit/ddl_audit.sql` | Crea el esquema `audit` (lotes, registro de cargas y registros rechazados). |
| 3 | `03_scripts/bronze/ddl_bronze.sql` | Crea las tablas Bronze. |
| 4 | `03_scripts/bronze/proc_load_bronze.sql` | Crea el procedimiento `bronze.load_bronze`. |
| 5 | `CALL bronze.load_bronze('C:/datasets')` | Carga los CSV en Bronze. |
| 6 | `03_scripts/silver/ddl_silver.sql` | Crea las tablas Silver. |
| 7 | `03_scripts/silver/proc_load_silver.sql` | Crea el procedimiento `silver.load_silver`. |
| 8 | `CALL silver.load_silver()` | Limpia y carga Silver. |
| 9 | `03_scripts/gold/ddl_gold.sql` | Crea las vistas Gold. |
| 10 | `03_scripts/security/roles_and_permissions.sql` | Roles y permisos por capa. |
| 11 | `04_tests/*.sql` | Validaciones de calidad. |

### Opción A: script maestro (recomendado)

```bash
psql -U postgres -d postgres -v dataset_path="C:/datasets" -f 00_setup/run_all.sql
```

> ⚠️ `run_all.sql` **elimina y recrea** la base de datos `datawarehouse`.

### Opción B: paso a paso

```bash
psql -U postgres -d postgres      -f 03_scripts/init_database.sql
psql -U postgres -d datawarehouse -f 03_scripts/audit/ddl_audit.sql
psql -U postgres -d datawarehouse -f 03_scripts/bronze/ddl_bronze.sql
psql -U postgres -d datawarehouse -f 03_scripts/bronze/proc_load_bronze.sql
psql -U postgres -d datawarehouse -c "CALL bronze.load_bronze('C:/datasets');"
psql -U postgres -d datawarehouse -f 03_scripts/silver/ddl_silver.sql
psql -U postgres -d datawarehouse -f 03_scripts/silver/proc_load_silver.sql
psql -U postgres -d datawarehouse -c "CALL silver.load_silver();"
psql -U postgres -d datawarehouse -f 03_scripts/gold/ddl_gold.sql
psql -U postgres -d datawarehouse -f 03_scripts/security/roles_and_permissions.sql
```

### Validar

```bash
psql -U postgres -d datawarehouse -f 04_tests/quality_checks_bronze.sql
psql -U postgres -d datawarehouse -f 04_tests/quality_checks_silver.sql
psql -U postgres -d datawarehouse -f 04_tests/quality_checks_gold.sql
```

## Operación

### Cargas recurrentes (sin recrear la base de datos)

```bash
psql -U postgres -d datawarehouse -v dataset_path="C:/datasets" -f 03_scripts/run_etl.sql
```

### Automatización con el Programador de tareas de Windows

```powershell
# Prueba manual (deja el log en logs/etl_<fecha>.log)
.\00_setup\run_etl.ps1 -DatasetPath "C:/datasets" -Port 5432

# Programar todos los días a las 02:00
schtasks /Create /TN "DWH_ETL_Diario" /SC DAILY /ST 02:00 /TR "powershell -ExecutionPolicy Bypass -File C:\ruta\sql-data-warehouse-project\00_setup\run_etl.ps1 -DatasetPath C:/datasets -Port 5432"
```

### Respaldo y restauración

```powershell
# Respaldo (conserva los últimos 7 días)
.\00_setup\backup_datawarehouse.ps1 -BackupDir "C:/backups/dwh" -Port 5432

# Programar el respaldo diario a las 03:00
schtasks /Create /TN "DWH_Backup_Diario" /SC DAILY /ST 03:00 /TR "powershell -ExecutionPolicy Bypass -File C:\ruta\sql-data-warehouse-project\00_setup\backup_datawarehouse.ps1 -BackupDir C:/backups/dwh -Port 5432"
```

```bash
# Restaurar
createdb   -U postgres datawarehouse
pg_restore -U postgres -d datawarehouse --clean --if-exists C:/backups/dwh/datawarehouse_<fecha>.dump
```

### Monitoreo

```sql
SELECT * FROM audit.vw_batch_summary ORDER BY batch_id DESC LIMIT 10;
SELECT * FROM audit.load_log WHERE status = 'FAILED' ORDER BY log_id DESC;
```

Más detalle en [02_docs/operations.md](../02_docs/operations.md).

## Problemas frecuentes

| Error | Causa | Solución |
|---|---|---|
| `Connection refused ... puerto 5432` | El servidor escucha en otro puerto (ver `port` en `postgresql.conf`). | Agregue `-p <puerto>` a cada comando `psql`, por ejemplo `-p 5000`. |
| `could not open file ... Permission denied` | El servicio de PostgreSQL no puede leer la carpeta (frecuente en OneDrive o Escritorio). | Copie `01_datasets` a `C:/datasets` y pase esa ruta a `load_bronze`. |
| `must be superuser or have privileges of the pg_read_server_files role` | El usuario no puede usar `COPY` desde archivo. | Use un usuario con el rol `dwh_engineer` (incluye `pg_read_server_files`) o `postgres`. |
| `El lote N de la capa bronze falló` | La carga falló y se revirtió. | Revise `audit.load_log` (columna `error_message`), corrija y vuelva a ejecutar. |
| `invalid byte sequence for encoding "UTF8"` | El CSV fue guardado con otra codificación. | Vuelva a guardar el archivo en UTF-8. |

### Alternativa sin permisos de servidor (`\copy`)

Si no es posible usar `COPY` en el servidor, cargue Bronze desde el cliente `psql`
después de crear las tablas (paso 3). Se indican las columnas porque las columnas
técnicas `dwh_` no vienen en los CSV:

```sql
TRUNCATE bronze.crm_cust_info, bronze.crm_prd_info, bronze.crm_sales_details,
         bronze.erp_cust_az12, bronze.erp_loc_a101, bronze.erp_px_cat_g1v2;
\copy bronze.crm_cust_info (cst_id, cst_key, cst_firstname, cst_lastname, cst_marital_status, cst_gndr, cst_create_date) FROM '01_datasets/source_crm/cust_info.csv' WITH (FORMAT csv, HEADER true)
\copy bronze.crm_prd_info (prd_id, prd_key, prd_nm, prd_cost, prd_line, prd_start_dt, prd_end_dt) FROM '01_datasets/source_crm/prd_info.csv' WITH (FORMAT csv, HEADER true)
\copy bronze.crm_sales_details (sls_ord_num, sls_prd_key, sls_cust_id, sls_order_dt, sls_ship_dt, sls_due_dt, sls_sales, sls_quantity, sls_price) FROM '01_datasets/source_crm/sales_details.csv' WITH (FORMAT csv, HEADER true)
\copy bronze.erp_cust_az12 (cid, bdate, gen) FROM '01_datasets/source_erp/CUST_AZ12.csv' WITH (FORMAT csv, HEADER true)
\copy bronze.erp_loc_a101 (cid, cntry) FROM '01_datasets/source_erp/LOC_A101.csv' WITH (FORMAT csv, HEADER true)
\copy bronze.erp_px_cat_g1v2 (id, cat, subcat, maintenance) FROM '01_datasets/source_erp/PX_CAT_G1V2.csv' WITH (FORMAT csv, HEADER true)
```
