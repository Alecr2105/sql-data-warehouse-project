# Modelo de datos — Esquema en estrella (capa Gold)

```mermaid
erDiagram
    DIM_CUSTOMERS ||--o{ FACT_SALES : "customer_key"
    DIM_PRODUCTS  ||--o{ FACT_SALES : "product_key"

    DIM_CUSTOMERS {
        bigint  customer_key PK
        int     customer_id
        varchar customer_number
        varchar first_name
        varchar last_name
        varchar country
        varchar marital_status
        varchar gender
        date    birthdate
        date    create_date
    }

    DIM_PRODUCTS {
        bigint  product_key PK
        int     product_id
        varchar product_number
        varchar product_name
        varchar category_id
        varchar category
        varchar subcategory
        varchar maintenance
        int     cost
        varchar product_line
        date    start_date
    }

    FACT_SALES {
        varchar order_number
        bigint  product_key FK
        bigint  customer_key FK
        date    order_date
        date    shipping_date
        date    due_date
        int     sales_amount
        int     quantity
        int     price
    }
```

## Reglas de negocio

- **Ventas:** `sales_amount = quantity * price`.
- **Productos:** solo se publica la versión vigente de cada producto (`prd_end_dt IS NULL`).
- **Género del cliente:** se usa el valor del CRM; si es `n/a`, se toma el del ERP.
- **Claves subrogadas:** se generan con `row_number()` y no tienen significado de negocio.

## Objeto agregado

`gold.report_sales_monthly` resume `gold.fact_sales` por año y mes (pedidos, clientes,
unidades y monto). Ver [data_catalog.md](data_catalog.md).
