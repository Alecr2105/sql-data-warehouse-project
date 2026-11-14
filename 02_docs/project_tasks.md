# Detalle de tareas del proyecto

Desglose del roadmap ([project_roadmap.puml](project_roadmap.puml)) en tareas verificables.
Cada tarea terminada se registra como uno o más commits en la rama `Alejandro`.

## 1. Análisis de requerimientos
- [x] Entender el objetivo y las especificaciones → [requirements.md](requirements.md)

## 2. Diseño de la arquitectura de datos
- [x] Elegir el enfoque: arquitectura Medallion (Bronze, Silver, Gold)
- [x] Definir las capas, el tipo de objeto, el método de carga y las transformaciones → [data_architecture.md](data_architecture.md)

## 3. Inicialización del proyecto
- [x] Crear el detalle de tareas del proyecto (este documento)
- [x] Definir la convención de nombres → [naming_conventions.md](naming_conventions.md)
- [x] Crear el repositorio Git y la estructura de carpetas (`00_setup` … `04_tests`)
- [x] Crear la base de datos y los esquemas → `03_scripts/init_database.sql`

## 4. Construir la capa Bronze
- [x] Analizar los sistemas de origen → [source_analysis.md](source_analysis.md)
- [x] Codificar la ingesta: DDL y `bronze.load_bronze` con `COPY` → `03_scripts/bronze/`
- [x] Validar la completitud y la estructura → `04_tests/quality_checks_bronze.sql`
- [x] Documentar: dibujar el flujo de datos → [data_flow.md](data_flow.md)
- [x] Commit en el repositorio

## 5. Construir la capa Silver
- [x] Explorar y entender los datos (perfilado) → `04_tests/data_profiling_bronze.sql`
- [x] Codificar la limpieza: DDL y `silver.load_silver` → `03_scripts/silver/`
- [x] Validar la exactitud de los datos → `04_tests/quality_checks_silver.sql`
- [x] Documentar: modelo de integración → [data_integration.md](data_integration.md)
- [x] Commit en el repositorio

## 6. Construir la capa Gold
- [x] Analizar los objetos de negocio (clientes, productos, ventas)
- [x] Codificar la integración: vistas del modelo en estrella → `03_scripts/gold/`
- [x] Validar la integridad del modelo → `04_tests/quality_checks_gold.sql`
- [x] Documentar: modelo de datos y catálogo → [data_model.md](data_model.md), [data_catalog.md](data_catalog.md)
- [x] Commit en el repositorio

## 7. Operación y buenas prácticas
- [x] Trazabilidad, monitoreo y registros rechazados → `03_scripts/audit/`
- [x] Seguridad por capa → `03_scripts/security/`
- [x] Automatización y respaldos → `03_scripts/run_etl.sql`, `00_setup/*.ps1`
- [x] Documentar la operación → [operations.md](operations.md)

## Flujo de ramas
`Alejandro` (desarrollo) → `Developer` (integración) → `main` (entrega, la promueve el responsable del proyecto).
