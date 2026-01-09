# Analysis Pipeline
**Doc Scope:** Documents SQL pipeline stages and their validation and analysis intent across the analytics lifecycle.


## [01_data_cleaning.sql](../sql/scripts/01_data_cleaning.sql)
**Purpose:** Validate data fitness for decision analysis; surface and isolate issues that would invalidate downstream conclusions.

| Section | Intent |
| --- | --- |
| Raw Data Ingestion | Provision staging tables for raw data |
| Data Load | Load source data into staging |
| Data Profiling & Structure Audit | Test column completeness and key integrity |
| Duplicate & Key Consistency | Identify duplicate records and key collisions |
| Hierarchy & Dimension Validation | Validate hierarchical field coherence |
| Continuous Variable Validation | Validate numeric ranges and distribution sanity |
| Data Corrections | Normalize mappings and enforce dimensional consistency |
| Data Quality Handling | Flag irrecoverable data quality failures |


## [02_exploratory_data_analysis.sql](../sql/scripts/02_exploratory_data_analysis.sql)
**Purpose:** Test whether demand can move the budget, kill weak narratives, and feed synthesis only.


| Section | Intent |
| --- | --- |
| Market Demand & Budget Absorption Gate | Test whether market scale is large enough to move allocation |
| Product Demand Concentration Gate | Test whether product demand concentration can safely guide allocation |
| Incentive Illusion Check: Pricing Context | Test whether demand is organic or incentive-driven enough to guide allocation |
| Fulfillment Behavior Boundary: Cost Context | Test whether fulfillment speed reflects scalable willingness to pay |
| Customer Segment Survival Check | Test whether segments earn allocation through scale and organic demand |