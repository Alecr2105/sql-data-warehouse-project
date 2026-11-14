# Análisis de los sistemas de origen

Primer paso de la construcción de la capa Bronze: **Analizar → Codificar → Validar → Documentar**.
Se responden las preguntas de negocio y técnicas de extracción y carga antes de escribir el código.

## 1. Contexto de negocio

| Pregunta | Respuesta |
|---|---|
| ¿Qué sistemas entregan datos? | **CRM** (clientes, productos y ventas) y **ERP** (datos demográficos, ubicación y categorías). |
| ¿Quién es el dueño de los datos? | Las áreas comerciales (CRM) y administrativas (ERP) de la empresa. |
| ¿Qué procesos de negocio cubren? | Venta de bicicletas, componentes, ropa y accesorios a clientes finales. |
| ¿Para qué se usarán? | Reportes de ventas por cliente, producto, país, categoría y periodo. |

## 2. Arquitectura e integración técnica

| Pregunta | Respuesta |
|---|---|
| ¿Cómo se almacenan los datos en el origen? | Exportaciones de tablas en archivos **CSV** (delimitador `,`, con encabezado, UTF-8). |
| ¿Cuál es la interfaz de integración? | **Archivos en carpetas**: `source_crm/` y `source_erp/`. No hay API ni conexión directa. |
| ¿Cómo se identifican las relaciones entre sistemas? | Por claves de negocio que requieren homologación (ver [data_integration.md](data_integration.md)). |

## 3. Extracción y carga (Extract & Load)

| Pregunta | Respuesta | Decisión |
|---|---|---|
| **¿Carga incremental o completa?** | Los archivos son extracciones completas de cada tabla y no traen una marca confiable de cambios. | **Carga completa** (truncate & insert) en Bronze y Silver. |
| **¿Alcance y necesidades históricas?** | El requisito pide trabajar solo con el conjunto de datos más reciente; no se requiere historial. | Cada carga reemplaza la anterior. Gold publica solo la versión vigente de cada producto. |
| **¿Tamaño esperado de las extracciones?** | 6 archivos, **5,2 MB** en total, unas 116 000 filas (ver tabla 4). | Volumen bajo: carga por lotes con `COPY`. |
| **¿Limitaciones de volumen?** | Ninguna para este volumen. La carga completa tarda menos de 1 segundo y la base de datos ocupa unos 42 MB. | No requiere particionamiento ni cargas paralelas. |
| **¿Cómo evitar impactar el rendimiento del origen?** | Se leen archivos ya exportados; el ETL nunca se conecta a CRM ni a ERP. | La carga se programa de madrugada (02:00) con el Programador de tareas. |
| **¿Autenticación y autorización?** | Los archivos se depositan en una carpeta local del servidor. | El servicio de PostgreSQL necesita permiso de lectura sobre la carpeta (`C:/datasets`) y el usuario del ETL el rol `pg_read_server_files` (incluido en `dwh_engineer`). Las contraseñas van en `pgpass.conf`, nunca en los scripts. |

> **Herramienta de carga:** el enunciado usa `BULK INSERT` de SQL Server. En PostgreSQL se
> utiliza su equivalente, `COPY ... FROM`, cuyo uso fue autorizado por el profesor.

## 4. Perfil de los archivos

| Sistema | Archivo | Tabla Bronze | Filas | Tamaño | Contenido |
|---|---|---|---:|---:|---|
| CRM | `cust_info.csv` | `crm_cust_info` | 18 494 | 835 KB | Información de clientes |
| CRM | `prd_info.csv` | `crm_prd_info` | 397 | 26 KB | Información actual e histórica de productos |
| CRM | `sales_details.csv` | `crm_sales_details` | 60 398 | 3,5 MB | Transacciones de ventas y pedidos |
| ERP | `CUST_AZ12.csv` | `erp_cust_az12` | 18 484 | 548 KB | Información adicional del cliente (fecha de nacimiento, género) |
| ERP | `LOC_A101.csv` | `erp_loc_a101` | 18 484 | 393 KB | Ubicación de los clientes (país) |
| ERP | `PX_CAT_G1V2.csv` | `erp_px_cat_g1v2` | 37 | 1 KB | Categorías de productos |

- **Rango de ventas:** pedidos del 29-12-2010 al 28-01-2014 (27 659 pedidos).
- **Formato de fechas:** ISO `yyyy-mm-dd`, salvo en ventas, donde vienen como entero `yyyymmdd`.
- **Problemas detectados:** ver [04_tests/data_profiling_bronze.sql](../04_tests/data_profiling_bronze.sql)
  y el resumen de registros rechazados o corregidos en [operations.md](operations.md).
