# Modelo de integración CRM ↔ ERP

Cómo se relacionan las tablas de los dos sistemas origen y qué transformación
de claves hace falta en Silver para poder unirlas.

```mermaid
flowchart LR
    subgraph CRM
        SD[crm_sales_details<br/>Ventas]
        PI[crm_prd_info<br/>Productos]
        CI[crm_cust_info<br/>Clientes]
    end
    subgraph ERP
        PX[erp_px_cat_g1v2<br/>Categorías]
        AZ[erp_cust_az12<br/>Fecha nacimiento]
        LO[erp_loc_a101<br/>País]
    end
    SD -- "sls_prd_key = prd_key" --> PI
    SD -- "sls_cust_id = cst_id" --> CI
    PI -- "cat_id = id" --> PX
    CI -- "cst_key = cid" --> AZ
    CI -- "cst_key = cid" --> LO
```

| Relación | Clave origen | Clave destino | Transformación en Silver |
|---|---|---|---|
| Ventas → Productos | `sls_prd_key` (`BK-R93R-62`) | `prd_key` (`BI-RB-BK-R93R-62`) | `prd_key = substring(prd_key FROM 7)` |
| Ventas → Clientes | `sls_cust_id` | `cst_id` | Ninguna |
| Productos → Categorías | `prd_key` (`BI-RB-...`) | `id` (`BI_RB`) | `cat_id = replace(substring(prd_key, 1, 5), '-', '_')` |
| Clientes → Datos adicionales | `cst_key` (`AW00011000`) | `cid` (`NASAW00011000`) | Quitar el prefijo `NAS` |
| Clientes → Ubicación | `cst_key` (`AW00011000`) | `cid` (`AW-00011000`) | Quitar el guion `-` |

## Flujo completo (lineage)

```mermaid
flowchart LR
    B1[bronze.crm_sales_details] --> S1[silver.crm_sales_details] --> G3[gold.fact_sales]
    B2[bronze.crm_prd_info]      --> S2[silver.crm_prd_info]      --> G2[gold.dim_products]
    B3[bronze.crm_cust_info]     --> S3[silver.crm_cust_info]     --> G1[gold.dim_customers]
    B4[bronze.erp_cust_az12]     --> S4[silver.erp_cust_az12]     --> G1
    B5[bronze.erp_loc_a101]      --> S5[silver.erp_loc_a101]      --> G1
    B6[bronze.erp_px_cat_g1v2]   --> S6[silver.erp_px_cat_g1v2]   --> G2
    G1 --> G3
    G2 --> G3
    G3 --> G4[gold.report_sales_monthly]
```
