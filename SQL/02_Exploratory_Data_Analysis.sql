
USE Super_Store

/*-------------------------------------------------------------------------------------------------*/
/*------------------------------ ADDING DATE RELATED COLUMNS --------------------------------------*/
/*-------------------------------------------------------------------------------------------------*/


-- Adding Date related columns
ALTER TABLE Stores
ADD MonthName	NVARCHAR(30) NULL, 
    MonthNo		TINYINT NULL,
    QuarterNo	NVARCHAR(5) NULL,
    Year		SMALLINT NULL;


/*-------------------------------------------------------------------------------------------------*/


-- Inspecting Result before populating the table
SELECT
    TOP 5 LEFT(DATENAME(MONTH,OrderDate),3) AS MonthName,
    MONTH(OrderDate) AS MonthNo,
    CONCAT('Q', DATEPART(QUARTER,OrderDate)) AS QuarterNo,
    YEAR(Orderdate) AS Year
FROM
    Stores;


/*-------------------------------------------------------------------------------------------------*/


-- Populating the columns.
BEGIN TRAN
UPDATE Stores
SET 
    MonthName = LEFT(DATENAME(MONTH, OrderDate), 3),
    QuarterNo = CONCAT('Q', DATEPART(QUARTER,OrderDate)),
    MonthNo = MONTH(OrderDate),
    Year = YEAR(OrderDate)
WHERE
    OrderDate IS NOT NULL;

--ROLLBACK;
--COMMIT;


/*-------------------------------------------------------------------------------------------------*/


-- Checking Result
SELECT
    TOP 5 *
FROM
    Stores;


/*-------------------------------------------------------------------------------------------------*/
/*------------------------------------- DATA EXPLORATION ------------------------------------------*/
/*-------------------------------------------------------------------------------------------------*/


/** Calculate Yearly sales, orders, Profit margin, and YoY sales increase **/

SELECT
    Year,
    FORMAT(SUM(Sales), 'N0') AS TotalSales,
    FORMAT(COUNT(Segment), 'N0') AS TotalOrders,
    FORMAT(SUM(Profit)/ SUM(Sales), 'P2') AS ProfitMargin,
    FORMAT(
        (SUM(Sales) - LAG(SUM(Sales)) OVER(ORDER BY Year)) / LAG(SUM(Sales)) OVER(ORDER BY Year)
        , 'P2') AS YoYSalesIncrease
FROM
    Stores
GROUP BY
    Year
ORDER BY
    Year DESC;


/*-------------------------------------------------------------------------------------------------*/


/** Calculates quarterly and monthly sales and orders totals to identify trends **/

SELECT
    QuarterNo,
    MonthName,
    FORMAT(SUM(Sales), 'N0') AS TotalSales,
    FORMAT(COUNT(Segment), 'N0') AS TotalOrders
FROM
    Stores
GROUP BY
    QuarterNo,
    MonthNo,
    MonthName
ORDER BY
    MonthNo;


/*-------------------------------------------------------------------------------------------------*/


/** Analyzes market performance by average sales, and order volume  **/

SELECT
    COUNT(DISTINCT Country) AS CountryCount,
    Market,
    FORMAT(AVG(Sales), 'N0') AS AvgSales,
    FORMAT(COUNT(Market), 'N0') AS TotalOrder
FROM
    Stores
GROUP BY
    Market
ORDER BY
    CountryCount; 


/*-------------------------------------------------------------------------------------------------*/

/** Calculates Market's Segments Total Sales Distribution **/

SELECT
    Market,
    FORMAT(Consumer, 'N0') AS ConsumerSales,
    FORMAT(Corporate, 'N0') AS CorporateSales,
    FORMAT([Home Office], 'N0') AS HomeOfficeSales
FROM
    (
    SELECT
        Market,
        Segment,
        Sales
    FROM
        Stores
        ) AS TableSource
            PIVOT
        (
            SUM(Sales)						-- Creates 3 columns that represents 
            FOR Segment						-- each segments total sales
            IN ([Consumer], [Corporate], [Home Office])
        ) AS PivoTable


/*-------------------------------------------------------------------------------------------------*/


/** Analyzes Total Orders, Sales for each segments and Average Sales per order **/

SELECT
    Segment,
    FORMAT(COUNT(Segment), 'N0') AS TotalOrders,
    FORMAT(SUM(Sales), 'N0') AS TotalSales,
    ROUND(CAST(AVG(Sales) AS FLOAT),2) AS AvgSales
FROM
    Stores
GROUP BY
    Segment
ORDER BY
    Segment;


/*-------------------------------------------------------------------------------------------------*/


/** Calculates Orders distribution in % for each segment, and discounted products impact **/

WITH OrderDistribution AS (
    SELECT                                                      -- Pivoted table with each segments
        QuarterNo,                                              -- data converted to percentage
        MonthName,
        SUM(CAST(Consumer AS FLOAT))  / SUM(SUM(Consumer)) OVER() AS Consumer,
        SUM(CAST(Corporate AS FLOAT)) / SUM(SUM(Corporate)) OVER()  AS Corporate,
        SUM(CAST([Home Office] AS FLOAT)) / SUM(SUM([Home Office])) OVER() AS HomeOffice
    FROM
    (
        SELECT
            QuarterNo,
            MonthName,
            MonthNo,
            ProductName,
            Segment
        FROM
            Stores
            ) AS TableSource
                PIVOT
            (
                COUNT(ProductName)                              -- Count order per segment
                FOR Segment
                IN ([Consumer], [Corporate], [Home Office])     -- Creates 3 columns for each segments
            ) AS PivotTable                                     -- with each having total order
    GROUP BY
        QuarterNo,
        MonthName
    ),
MonthlyDiscounts AS (
    SELECT
        MonthNo,
        MonthName,
        SUM(CASE
                WHEN Discount > 0.000 THEN 1                    -- 1 represents a product was sold with
                ELSE 0                                          -- with discount. Enables to calculate
            END) AS DiscountedProductCount                      -- total products sold with discount
    FROM
        Stores
    GROUP BY
        MonthNo,
        MonthName
)
SELECT                                                          -- Formatted data for clarity
    TD.MonthName,
    FORMAT(TD.Consumer, 'P2') AS 'ConsumerOrder(%)',
    FORMAT(TD.Corporate, 'P2') AS 'CorporateOrder(%)',
    FORMAT(TD.HomeOffice, 'P2') AS 'HomeOfficeOrder(%)',
    FORMAT(MD.DiscountedProductCount, 'N0') AS DiscountedProductCount
FROM
    OrderDistribution AS TD
        JOIN
    MonthlyDiscounts AS MD
    ON TD.MonthName = MD.MonthName
ORDER BY
    TD.QuarterNo,
    MD.MonthNo;


/*-------------------------------------------------------------------------------------------------*/


/** Creating a table to store a random sample, avoiding NEWID() reordering for reproducibility. **/

IF OBJECT_ID('RandomSample_Sales') IS NOT NULL DROP TABLE RandomSample_Sales;

CREATE TABLE RandomSample_Sales (
    ShippingCost	DECIMAL(10,2),
    Discount		DECIMAL(5,3),
    Sales		DECIMAL(10,2)
)

-- Populating Random Sample Table
INSERT INTO RandomSample_Sales (ShippingCost, Discount, Sales)
    SELECT 
        TOP 1000
        ShippingCost,
        Discount,
        Sales
    FROM 
        Stores
    ORDER BY 
        NEWID();


-- Checking Result

SELECT
    *
FROM
    RandomSample_Sales;


/*-------------------------------------------------------------------------------------------------*/


/** Creates a benchmark to filter products perfomance by SubCategory **/

WITH ProductSalesInfo AS (
    SELECT
        Category,
        SubCategory,
        ProductName,
        AVG(Sales) AS AvgSales,
        SUM(Sales) AS TotalSales
    FROM
        Stores
    GROUP BY
        Category,
        SubCategory,
        ProductName
    ),
SubCategoryBenchmark AS (                               -- Percentiles for each Subcategory
    SELECT                                              -- AvgSales that would serve as Benchmark
        DISTINCT SubCategory,
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY AvgSales) OVER (PARTITION BY SubCategory) AS P25,
        PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY AvgSales) OVER (PARTITION BY SubCategory) AS P50,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY AvgSales) OVER (PARTITION BY SubCategory) AS P75
    FROM
        ProductSalesInfo
)
SELECT
    PSI.Category,
    PSI.SubCategory,
    PSI.ProductName,
    PSI.TotalSales,
    CASE                                                -- Flag for products AvgSales performance
        WHEN PSI.AvgSales >= SCB.P75 THEN 'High'
        WHEN PSI.AvgSales >= SCB.P50 AND PSI.AvgSales < SCB.P75 THEN 'Moderate'
        ELSE 'Low'
    END AS AvgSalesPerformance
INTO #ProductPerformance                                -- Saved into temporary table
FROM
    ProductSalesInfo AS PSI
        JOIN
    SubCategoryBenchmark AS SCB
    ON PSI.SubCategory = SCB.SubCategory
ORDER BY
    PSI.Category,
    PSI.AvgSales DESC;


/** Calcutes Product count, Total Sales and Sales distribution in % for each Product Performance **/

SELECT
    AvgSalesPerformance,
    COUNT(ProductName) AS ProductCount,
    FORMAT(SUM(TotalSales), 'N0') AS TotalSales,
    FORMAT(SUM(TotalSales)/ SUM(SUM(TotalSales)) OVER(), 'P2') AS 'SalesDistribution%'
FROM
    #ProductPerformance
GROUP BY
    AvgSalesPerformance
ORDER BY
    SUM(TotalSales) DESC;


/*-------------------------------------------------------------------------------------------------*/


/** Calculates the percentage distribution of total sales within each categories performance group **/

SELECT
    Category,                                           -- Formatted for clarity
    FORMAT(High, 'P2') AS High,
    FORMAT(Moderate, 'P2') AS Moderate,
    FORMAT(Low, 'P2') AS Low
FROM
(
    
    SELECT                                              -- Calculates Sales distribution
        Category,                                       -- percentage for each category
        AvgSalesPerformance,                            -- and product performance
        SUM(TotalSales) / SUM(SUM(TotalSales)) OVER(PARTITION BY Category) AS TotalSalesPercentage
    FROM
        #ProductPerformance
    GROUP BY
        Category,
        AvgSalesPerformance
    )AS TableSource
        PIVOT
        (
        SUM(TotalSalesPercentage)                       -- Sum of total Sales percentage
        FOR AvgSalesPerformance	                        -- for each product performance
        IN ([High], [Moderate], [Low])
        )AS PivotTable;

