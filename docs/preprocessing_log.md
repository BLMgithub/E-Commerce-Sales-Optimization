# Preprocessing Log
## 1. Data Quality & Field Handling

**Doc Scope:** Field-level documentation of data quality issues, corrections, and data handling decisions applied during preprocessing.

**Related script:** [`01_Data_Cleaning.sql`](../sql/scripts/01_Data_Cleaning.sql)

**Output dataset:** [`Stores.csv`](../data/processed/Stores.csv)

| Field Name   | Issue Identified                                       | Action Taken                        | Notes                                                               |
| ------------ | ------------------------------------------------------ | ----------------------------------- | ------------------------------------------------------------------- |
| CustomerName | Maps to multiple CustomerIDs                           | Excluded from analysis              | Non-unique identifier; not required for revenue optimization        |
| CustomerID   | One-to-many mapping with CustomerName                  | Retained but not used for grouping  | Used only as row-level identifier                                   |
| ProductName  | Maps to multiple ProductIDs                            | Retained for analysis               | Core business dimension                                             |
| ProductID    | One-to-many mapping with ProductName                   | Ignored in analysis                 | Adds ambiguity without analytical value                             |
| Market       | Inconsistent mapping with Country                      | Corrected to canonical mapping      | Austria to EU, Mongolia to APAC                                     |
| Region       | Mixed geographic grain; duplicates Market-level values | Excluded from hierarchical analysis | Region reused as both macro and sub-market                          |
| SubCategory  | Inconsistent mapping with ProductName                  | Corrected                           | Staples standardized to Fasteners                                   |
| Profit       | Extreme and persistent negative values                 | Excluded from KPI analysis          | No fields available to validate behavior                            |