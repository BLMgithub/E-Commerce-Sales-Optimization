/* ============================================================
    Project: Growth Budget Allocation: $3M Strategy for 2015
    File: 03_reporting_extract.sql
    Author: Bryan Melvida
   
    Purpose:
    - Extract reporting data derived from validated analysis outputs
    - Save shaped result as CSV in growth-budget-allocation\data\exported_tables
   ============================================================ */


USE global_store_sales


/* ============================================================
    REPORTING DATA SHAPING
   ------------------------------------------------------------
    - Apply minimal, report-facing preprocessing to reduce Power BI transformations
   ============================================================ */

---------------------------------------------------------------
-- FACT TABLE
---------------------------------------------------------------

SELECT
    market AS [Market],
    CASE 
        WHEN market IN ('APAC', 'EU', 'US', 'LATAM') THEN 1
        ELSE 0
    END AS [Is Core Market],
    country AS [Country],
    sales AS [Sales],
    discount AS [Discount],
    CASE WHEN discount > 0 THEN 1
        ELSE 0
    END AS [Discount Applied],
    category AS [Category],
    ship_mode AS [Ship Mode],
    order_date AS [Order Date],
    CASE 
        WHEN ship_date IS NOT NULL 
            AND ship_date >= order_date
        THEN DATEDIFF(DAY, order_date, ship_date)
        ELSE NULL
    END AS [Shipping Days],
    shipping_cost AS [Shipping Cost],
    segment AS [Segment]
FROM sales_transaction;



---------------------------------------------------------------
-- DATE TABLE
---------------------------------------------------------------

WITH date_bounds AS (
    SELECT 
        MIN(order_date) AS min_date,
        MAX(order_date) AS max_date
    FROM sales_transaction
),
calendar AS (
    SELECT min_date AS [Date]
    FROM date_bounds
    UNION ALL -- stack generated dates with existing rows
    SELECT DATEADD(DAY, 1, [Date])
    FROM calendar
    JOIN date_bounds ON [Date] < max_date -- stop condition
)
SELECT
    [Date] AS [Date],
    YEAR([Date]) AS [Year],
    MONTH([Date]) AS [Month],
    DATENAME(MONTH, [Date]) AS [Month Name],
    FORMAT([Date], 'yyyy-MM') AS [Year Month]
FROM calendar
OPTION (MAXRECURSION 0); -- remove recursion cap



/* ============================================================
    END OF REPORTING EXTRACT SCRIPT
   ============================================================ */