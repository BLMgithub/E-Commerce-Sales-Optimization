# Analysis Pipeline
**Doc Scope:** Documents SQL pipeline stages and their validation and analysis intent across the analytics lifecycle.


## [01_data_cleaning.sql](../sql/scripts/01_data_cleaning.sql)
**Purpose:** Ingest raw data and run early quality checks before analysis.

| Section                          | Intent                                                   |
| -------------------------------- | -------------------------------------------------------- |
| Raw Data Ingestion               | Create staging tables for raw data storage               |
| Data Load                        | Import source CSV data into staging                      |
| Data Profiling & Structure Audit | Assess column completeness and uniqueness                |
| Duplicate & Key Consistency      | Detect duplicate records and key conflicts               |
| Hierarchy & Dimension Validation | Validate hierarchical field consistency                  |
| Continuous Variable Validation   | Verify ranges, distributions, and invalid numeric values |
| Data Corrections                 | Enforce consistency and standardize mappings             |
| Data Quality Handling            | Assess unfixable or irrecoverable data quality issues    |


## [02_exploratory_data_analysis.sql](../sql/scripts/02_exploratory_data_analysis.sql)
**Purpose:** Analyze demand behavior, product mix, pricing sensitivity, fulfillment cost effects, growth signals, and segment contribution.

| Section                                          | Intent                                                       |
| ------------------------------------------------ | ------------------------------------------------------------ |
| Demand Concentration & Market Share Contribution | Assess how demand and revenue are distributed across markets |
| Product Demand & Mix Performance                 | Evaluate product-level demand and sales mix contribution     |
| Pricing & Discount Sensitivity                   | Measure demand response to pricing and discount changes      |
| Fulfillment & Cost Impact on Demand              | Evaluate how delivery performance and cost influence demand  |
| Growth Signals & Opportunity Gaps                | Detect emerging growth trends and unmet market opportunities |
| Segment Contribution & Demand Quality            | Assess segment demand reliability and business impact        |