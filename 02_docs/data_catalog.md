# Catálogo de datos — Capa Gold

La capa Gold es la representación de los datos para el negocio. Está organizada como un
**esquema en estrella** con dimensiones, una tabla de hechos y un reporte agregado.
Todos los objetos son **vistas** sobre la capa Silver.

---

## 1. `gold.dim_customers`

**Propósito:** información de los clientes enriquecida con datos demográficos y geográficos.

| Columna | Tipo | Descripción |
|---|---|---|
| `customer_key` | BIGINT | Clave subrogada que identifica de forma única cada cliente en la dimensión. |
| `customer_id` | INT | Identificador numérico del cliente en el CRM. |
| `customer_number` | VARCHAR(50) | Código alfanumérico del cliente, usado para enlazar con el ERP (ej. `AW00011000`). |
| `first_name` | VARCHAR(50) | Nombre del cliente. |
| `last_name` | VARCHAR(50) | Apellido del cliente. |
| `country` | VARCHAR(50) | País de residencia (ej. `Australia`); `n/a` si no se conoce. |
| `marital_status` | VARCHAR(50) | Estado civil: `Married`, `Single` o `n/a`. |
| `gender` | VARCHAR(50) | Género: `Male`, `Female` o `n/a`. El CRM es la fuente principal y el ERP el respaldo. |
| `birthdate` | DATE | Fecha de nacimiento (ERP). Las fechas futuras se reemplazan por NULL. |
| `create_date` | DATE | Fecha de creación del cliente en el CRM. |

## 2. `gold.dim_products`

**Propósito:** información de los productos vigentes y sus categorías.

| Columna | Tipo | Descripción |
|---|---|---|
| `product_key` | BIGINT | Clave subrogada que identifica de forma única cada producto. |
| `product_id` | INT | Identificador interno del producto en el CRM. |
| `product_number` | VARCHAR(50) | Código alfanumérico del producto (ej. `BK-R93R-62`). |
| `product_name` | VARCHAR(50) | Nombre descriptivo del producto. |
| `category_id` | VARCHAR(50) | Identificador de la categoría (enlace con el ERP, ej. `BI_RB`). |
| `category` | VARCHAR(50) | Categoría general (ej. `Bikes`, `Components`). |
| `subcategory` | VARCHAR(50) | Subcategoría (ej. `Road Bikes`). |
| `maintenance` | VARCHAR(50) | Indica si el producto requiere mantenimiento (`Yes` / `No`). |
| `cost` | INT | Costo base del producto. |
| `product_line` | VARCHAR(50) | Línea de producto: `Road`, `Mountain`, `Touring`, `Other Sales` o `n/a`. |
| `start_date` | DATE | Fecha desde la cual el producto está disponible. |

## 3. `gold.fact_sales`

**Propósito:** transacciones de venta para análisis. Grano: una línea de pedido.

| Columna | Tipo | Descripción |
|---|---|---|
| `order_number` | VARCHAR(50) | Identificador del pedido (ej. `SO54496`). |
| `product_key` | BIGINT | Clave subrogada que enlaza con `gold.dim_products`. |
| `customer_key` | BIGINT | Clave subrogada que enlaza con `gold.dim_customers`. |
| `order_date` | DATE | Fecha del pedido (NULL si el origen traía una fecha inválida). |
| `shipping_date` | DATE | Fecha de envío. |
| `due_date` | DATE | Fecha de vencimiento del pago. |
| `sales_amount` | INT | Monto de la línea (`quantity * price`). |
| `quantity` | INT | Unidades vendidas. |
| `price` | INT | Precio unitario. |

## 4. `gold.report_sales_monthly`

**Propósito:** ventas agregadas por año y mes para reportes de tendencia.

| Columna | Tipo | Descripción |
|---|---|---|
| `order_year` | INT | Año del pedido. |
| `order_month` | INT | Mes del pedido (1–12). |
| `total_orders` | BIGINT | Cantidad de pedidos distintos. |
| `total_customers` | BIGINT | Cantidad de clientes distintos que compraron. |
| `total_quantity` | BIGINT | Unidades vendidas. |
| `total_sales` | BIGINT | Monto total vendido. |

---

### Ejemplos de consulta

```sql
-- Ventas por país
SELECT c.country, sum(f.sales_amount) AS total_sales
FROM gold.fact_sales f
JOIN gold.dim_customers c USING (customer_key)
GROUP BY c.country
ORDER BY total_sales DESC;

-- Ventas por categoría de producto
SELECT p.category, sum(f.sales_amount) AS total_sales
FROM gold.fact_sales f
JOIN gold.dim_products p USING (product_key)
GROUP BY p.category
ORDER BY total_sales DESC;
```
