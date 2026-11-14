# Flujo de datos (Data Lineage)

```mermaid
flowchart LR
    subgraph Fuentes
        direction TB
        F1[CRM · cust_info.csv]
        F2[CRM · prd_info.csv]
        F3[CRM · sales_details.csv]
        F4[ERP · CUST_AZ12.csv]
        F5[ERP · LOC_A101.csv]
        F6[ERP · PX_CAT_G1V2.csv]
    end
    subgraph Bronze
        direction TB
        B1[crm_cust_info]
        B2[crm_prd_info]
        B3[crm_sales_details]
        B4[erp_cust_az12]
        B5[erp_loc_a101]
        B6[erp_px_cat_g1v2]
    end
    F1 --> B1
    F2 --> B2
    F3 --> B3
    F4 --> B4
    F5 --> B5
    F6 --> B6
```

| Archivo origen | Tabla Bronze | Filas | Proceso |
|---|---|---:|---|
| `source_crm/cust_info.csv`     | `bronze.crm_cust_info`     | 18 494 | `bronze.load_bronze` |
| `source_crm/prd_info.csv`      | `bronze.crm_prd_info`      |    397 | `bronze.load_bronze` |
| `source_crm/sales_details.csv` | `bronze.crm_sales_details` | 60 398 | `bronze.load_bronze` |
| `source_erp/CUST_AZ12.csv`     | `bronze.erp_cust_az12`     | 18 484 | `bronze.load_bronze` |
| `source_erp/LOC_A101.csv`      | `bronze.erp_loc_a101`      | 18 484 | `bronze.load_bronze` |
| `source_erp/PX_CAT_G1V2.csv`   | `bronze.erp_px_cat_g1v2`   |     37 | `bronze.load_bronze` |
