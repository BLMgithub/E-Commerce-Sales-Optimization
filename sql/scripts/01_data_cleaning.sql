/* ============================================================
    Project: E-Commerce Sales Optimization
    File: 01_data_cleaning.sql
    Author: Bryan Melvida
   
    Purpose:
    - Ingest raw transactional data
    - Assess data quality, consistency, and anomalies
    - Apply targeted data corrections prior to analysis

    DATA NOTES:
    - Source: Global-Superstore.csv
   ============================================================ */


USE global_stores_sales;


/* ============================================================
    RAW DATA INGESTION
   ------------------------------------------------------------
    - Create a staging table to store raw data
   ============================================================ */


IF OBJECT_ID('sales_transaction') IS NOT NULL DROP TABLE sales_transaction;

CREATE TABLE sales_transaction (
    row_id           INT NULL,
    order_id         NVARCHAR(70) NULL,
    order_date       DATE NULL,
    ship_date        DATE NULL,
    ship_mode        NVARCHAR(30) NULL,
    customer_id      NVARCHAR(30) NULL,
    customer_name    NVARCHAR(70) NULL,
    segment          NVARCHAR(30) NULL,
    city             NVARCHAR(100) NULL,
    state            NVARCHAR(100) NULL,
    country          NVARCHAR(100) NULL,
    market           NVARCHAR(30) NULL,
    region           NVARCHAR(30) NULL,
    product_id       NVARCHAR(100) NULL,
    category         NVARCHAR(30) NULL,
    subcategory      NVARCHAR(30) NULL,
    product_name     NVARCHAR(255) NULL,
    sales            DECIMAL(10,2) NULL,
    quantity         TINYINT NULL,
    discount         DECIMAL(5,3) NULL,
    profit           DECIMAL(10,2) NULL,
    shipping_cost    Decimal(10,2) NULL,
    order_priority   NVARCHAR(30) NULL
    );


/* ============================================================
    DATA LOAD
   ------------------------------------------------------------
    - Import raw CSV data into the staging table
   ============================================================ */


BULK INSERT sales_transaction
FROM 'E:\E-Commerce-Sales-Optimization\data\raw\Global-Superstore.csv'
WITH (
    FORMAT= 'CSV',
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n'
    );


-- verification
SELECT TOP 10 *
FROM sales_transaction
ORDER BY NEWID();


/* ============================================================
    DATA PROFILING & STRUCTURE AUDIT
   ------------------------------------------------------------
    - Understand column-level completeness and uniqueness
    - Identify early red flags before deeper analysis
   ============================================================ */

-- data profile summary
DECLARE @profile_summary NVARCHAR(MAX);

SELECT @profile_summary = 
    STRING_AGG(
        CAST(
            'SELECT 
                ''' + sys_col.name + ''' AS column_name, ' +
                ''''+ info_col.DATA_TYPE +''' AS data_type, ' +
                'COUNT(CASE WHEN ' + sys_col.name + ' IS NULL THEN 1 END) AS null_count, ' +
                'COUNT(DISTINCT ' + sys_col.name +') AS count_distinct '+
             'FROM sales_transaction'
                AS NVARCHAR(MAX)), -- Prevents STRING_AGG error (8,000-byte limit)
            ' UNION ALL '
            )
FROM sys.columns AS sys_col
JOIN INFORMATION_SCHEMA.Columns as info_col
    ON sys_col.name = info_col.COLUMN_NAME
WHERE sys_col.object_id = OBJECT_ID('sales_transaction')
    AND info_col.TABLE_NAME = 'sales_transaction';

EXEC(@profile_summary);



/* ============================================================
    DUPLICATE & KEY CONSISTENCY CHECKS
   ------------------------------------------------------------
    - Detect duplicate records
    - Validate ID to name relationships
   ============================================================ */

-- duplicate detection
DECLARE @duplicate_check NVARCHAR(MAX);

SELECT @duplicate_check =
    'SELECT 
        COUNT(*) AS duplicate_counter,
        ' + STRING_AGG(QUOTENAME(name), ', ') + '
    FROM sales_transaction 
    GROUP BY
        ' + STRING_AGG(QUOTENAME(name), ', ') + '
    HAVING COUNT(*) > 1'

FROM sys.columns
WHERE object_id = OBJECT_ID('sales_transaction');

EXEC(@duplicate_check);


-- customer_id to customer_name consistency
SELECT
    COUNT(DISTINCT customer_name) AS customer_count_distinct,
    COUNT(DISTINCT customer_id) AS customer_id_count_distinct
FROM sales_transaction;

-- product_id to product_name consistency
SELECT
    COUNT(DISTINCT product_name) AS product_count_distinct,
    COUNT(DISTINCT product_id) AS product_id_count_distinct
FROM sales_transaction;


/* ------------------------------------------------------------
    FINDINGS
   ------------------------------------------------------------
    - customer_id to customer_name mismatches: 795 records
    - product_id to product_name mismataches: 6,504 records
   ------------------------------------------------------------ */



/* ============================================================
    HIERARCHY & DIMENSION VALIDATION
   ------------------------------------------------------------
    - Validate Market to Country Hierarchies
    - Validate Category to SubCategory to Product Hierarchies
   ============================================================ */


---------------------------------------------------------------
-- MARKET TO COUNTRY HIERARCHY COVERAGE
---------------------------------------------------------------

-- market distribution
SELECT
    market,
    COUNT(DISTINCT country) AS country_count
FROM sales_transaction
GROUP BY market;


-- market to region consistency check
SELECT
    DISTINCT(market),
    region
FROM sales_transaction
ORDER BY market;


-- market to country hierarchy consistency check
SELECT
    COUNT(DISTINCT country) AS country_count_distinct,
    COUNT(DISTINCT CONCAT(market,country)) AS market_country_map_count
FROM sales_transaction;


---------------------------------------------------------------
-- CATEGORY TO PRODUCT NAME HIERARCHY COVERAGE
---------------------------------------------------------------

-- category distribution
SELECT
    category,
    COUNT(DISTINCT subcategory) AS subcategory_count
FROM sales_transaction
GROUP BY category;

-- category to subcategory hierarchy consistency check
SELECT
    COUNT(DISTINCT subcategory) AS subcategory_count_distinct,
    COUNT(DISTINCT CONCAT(category, subcategory)) AS category_subcategory_map_count
FROM sales_transaction;


-- subcategory distribution
SELECT
    category,
    subcategory,
    COUNT(DISTINCT product_name) AS product_name_count
FROM sales_transaction
GROUP BY 
    category,
    subcategory
ORDER BY 
    category,
    product_name_count DESC;

-- subcategory to product hierarchy consistency check
SELECT
    COUNT(DISTINCT product_name) AS product_count_distinct,
    COUNT(DISTINCT CONCAT(subcategory, product_name)) AS subcategory_product_map_count
FROM sales_transaction;


/* ------------------------------------------------------------
    FINDINGS
   ------------------------------------------------------------
    - market to region: Region reused as both macro and sub-market
    - market to country: 149 Market–Country combinations across 147 countries
    - subcategory to product_name: 3,797 Subcategory–Product combinations across 3,788 products
   ------------------------------------------------------------ */



/* ============================================================
    CONTINUOUS VARIABLE VALIDATION
   ------------------------------------------------------------
    - Validate numeric ranges
   ============================================================ */


-- temporarly store continuous variables for range analysis
SELECT column_name
INTO #continuous_variables
FROM (VALUES ('Sales'), ('Quantity'), ('Discount'), ('Profit'), ('ShippingCost')) AS list_to(column_name)

-- Calculate Min, Avg, and  Max values for continuous variables
DECLARE @summary_stats NVARCHAR(MAX);

SELECT @summary_stats =
    STRING_AGG(
        'SELECT ''' + name + ''' AS column_name,
                MIN(' + name + ') AS min,
                AVG(' + name + ') AS avg,
                MAX(' + name + ') AS max
         FROM sales_transaction',
        ' UNION ALL '
    )
FROM sys.columns AS sys_col
JOIN #continuous_variables AS CV
  ON sys_col.name = CV.column_name
WHERE object_id = OBJECT_ID('sales_transaction');

EXEC(@summary_stats);


/* ------------------------------------------------------------
    FINDINGS
   ------------------------------------------------------------
    - Profit shows extreme negative values relative to sales (-6,599.98 vs minimum sales of 0.44)
   ------------------------------------------------------------ */


/* ============================================================
    DATA QUALITY CORRECTIONS
   ------------------------------------------------------------
    - Enforce consistent Market–Country hierarchy
    - Standardize SubCategory–Product mapping
   ============================================================ */


---------------------------------------------------------------
-- ENFORCE MARKET TO COUNTRY HIERARCHY
---------------------------------------------------------------

-- identify countries mapped to more than one market
SELECT
    country,
    COUNT(DISTINCT market) AS market_count_distinct
FROM sales_transaction
GROUP BY
    country
HAVING
    COUNT(DISTINCT market) > 1;

-- review affected market to country combinations
SELECT
    country,
    market
FROM sales_transaction
WHERE country IN ('Austria', 'Mongolia')
GROUP BY
    country,
    market;

-- prepare corrected market mapping
SELECT
    row_id,
    CASE
        WHEN country = 'Austria'  THEN 'EU'
        WHEN country = 'Mongolia' THEN 'APAC'
    END AS correct_market
INTO #market_to_country_map
FROM sales_transaction
WHERE
    market = 'EMEA'
    AND country IN ('Austria','Mongolia');

-- apply market to country hierarchy corrections
BEGIN TRAN;

UPDATE sales_transaction
SET
    market = MC.correct_market
FROM sales_transaction AS ST
JOIN #market_to_country_map AS MC
    ON ST.row_id = MC.row_id;

-- COMMIT;



---------------------------------------------------------------
-- STANDARDIZE SUBCATEGORY TO PRODUCT MAPPING
---------------------------------------------------------------

-- identify products mapped to multiple subcategories
WITH duplicates AS (
    SELECT
        product_name,
        COUNT(DISTINCT subcategory) AS subcategory_count_distinct
    FROM sales_transaction
    GROUP BY
        product_name
)
SELECT
    ST.category,
    ST.subcategory,
    ST.product_name
FROM sales_transaction AS ST
JOIN duplicates AS DU
    ON ST.product_name = DU.product_name
WHERE
    DU.subcategory_count_distinct > 1
GROUP BY
    ST.category,
    ST.subcategory,
    ST.product_name;

-- prepare corrected subcategory and category mapping
SELECT
    row_id,
    subcategory,
    product_name,
    'Fasteners' AS correct_subcategory,
    'Office Supplies' AS correct_category
INTO #subcategory_to_product_name_map
FROM sales_transaction
WHERE
    product_name = 'Staples'
    AND subcategory != 'Fasteners';

-- apply subcategory to product hierarchy corrections
BEGIN TRAN;

UPDATE sales_transaction
SET
    subcategory = SP.correct_subcategory,
    category = SP.correct_category
FROM sales_transaction AS ST
JOIN #subcategory_to_product_name_map AS SP
    ON SP.row_id = ST.row_id;

-- COMMIT;




/* ============================================================
    DATA QUALITY HANDLING DECISIONS
   ------------------------------------------------------------
    - Evaluate Market to Region consistency
    - Evaluate customer_id to customer_name consistency
    - Evaluate product_id to product_name consistency
    - Assess validity of Negative Profit records
   ============================================================ */


---------------------------------------------------------------
-- MARKET TO REGION CONSISTENCY CHECK
---------------------------------------------------------------

-- identify records where market is used in region
SELECT 
    DISTINCT(ST.market),
    ST.region
FROM sales_transaction AS ST
WHERE ST.region IN (
    SELECT DISTINCT market
    FROM sales_transaction
)
ORDER BY
    ST.market;



---------------------------------------------------------------
-- CUSTOMER_ID TO CUSTOMER_NAME CONSISTENCY CHECK
---------------------------------------------------------------

-- identify customer_names mapped to multiple customer_ids and multiple regions
SELECT
    customer_name,
    COUNT(DISTINCT customer_id) AS customer_id_count_distinct,
    COUNT(DISTINCT region) AS registered_region_count_distinct
FROM sales_transaction
GROUP BY customer_name;



---------------------------------------------------------------
-- PRODUCT_ID TO PRODUCT_NAME CONSISTENCY CHECK
---------------------------------------------------------------

-- identify product_name mapped to multiple product_id
SELECT
    product_name,
    COUNT(DISTINCT product_id) AS product_id_count_distinct
FROM sales_transaction
GROUP BY product_name
HAVING COUNT(DISTINCT product_id) > 1;


---------------------------------------------------------------
-- NEGATIVE PROFIT ASSESSMENT
---------------------------------------------------------------

-- identify records with negative profit
SELECT *
FROM sales_transaction
WHERE profit < 0
ORDER BY profit ASC;


-- assess magnitude and persistence of negative profit
WITH negative_profit_records AS (
    SELECT 
        YEAR(order_date) as order_year,
        SUM(profit) AS negative_profit
    FROM sales_transaction
    WHERE profit < 0
    GROUP BY YEAR(order_date)
)
,positive_profit_records AS (
    SELECT 
        YEAR(order_date) as order_year, 
        SUM(profit) AS positive_profit
    FROM sales_transaction
    WHERE profit > 0
    GROUP BY YEAR(order_date)
)
SELECT
    NP.order_year,
    FORMAT(NP.negative_profit, 'N0') AS negative_profit,
    FORMAT(PP.positive_profit, 'N0') AS positive_profit,
    FORMAT(
        ABS(NP.negative_profit) / PP.positive_profit, 'P2'
    ) AS negative_positive_ratio
FROM negative_profit_records AS NP
JOIN positive_profit_records AS PP
  ON NP.order_year = PP.order_year
ORDER BY NP.order_year;



/* ------------------------------------------------------------
    DATA HANDLING OUTCOMES
   ------------------------------------------------------------
    - Region excluded due to non-fixable hierarchy inconsistencies
    - customer_name excluded due to non-unique customer_id mapping
    - product_id excluded due to non-unique product_name mapping
    - Profit excluded from KPI analysis due to unexplained extreme and persistent negative values
   ------------------------------------------------------------ */


/* ============================================================
    END OF DATA CLEANING SCRIPT
   ============================================================ */