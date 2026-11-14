# Requisitos del proyecto

## Construcción del Almacén de Datos (Ingeniería de Datos)

### Objetivo
Desarrollar un almacén de datos moderno para consolidar información de ventas,
permitiendo generar reportes analíticos y facilitar la toma de decisiones informadas.

> Motor utilizado: **PostgreSQL** (el enunciado original usa SQL Server; los conceptos
> se trasladan 1:1: `BULK INSERT` → `COPY`, `CREATE OR ALTER PROCEDURE` → `CREATE OR REPLACE PROCEDURE`).
> El uso de `COPY` para la ingesta en PostgreSQL fue autorizado por el profesor.

### Especificaciones

| Especificación | Descripción |
|---|---|
| **Fuentes de datos** | Importar información de dos sistemas de origen (ERP y CRM), proporcionados mediante archivos CSV. |
| **Calidad de los datos** | Limpiar y resolver los problemas de calidad de los datos antes de realizar los análisis. |
| **Integración** | Combinar ambas fuentes en un único modelo de datos, fácil de utilizar y diseñado para consultas analíticas. |
| **Alcance** | Trabajar únicamente con el conjunto de datos más reciente. No se requiere historial. |
| **Documentación** | Documentar claramente el modelo de datos para usuarios de negocio y equipos de análisis. |

## Fases del proyecto (roadmap)

1. Análisis de requerimientos
2. Diseño de la arquitectura de datos
3. Inicialización del proyecto (tareas, convención de nombres, repositorio Git, base de datos y esquemas)
4. Construir capa Bronze (analizar orígenes → ingesta → validar → documentar → commit)
5. Construir capa Silver (analizar → limpiar → validar → documentar → commit)
6. Construir capa Gold (analizar → modelar → validar → documentar → commit)

Ver `project_roadmap.puml` y el detalle de tareas en [project_tasks.md](project_tasks.md).

## Flujo de trabajo con Git

- `main`: versión estable entregable (solo se actualiza desde `Developer`).
- `Developer`: integración de los cambios terminados.
- `Alejandro`: rama de trabajo personal; cada paso del roadmap se registra como un commit.
- Mensajes de commit con formato *Conventional Commits* (`feat`, `docs`, `test`, `chore`, `data`).
