
USE Super_Store

/*-------------------------------------------------------------------------------------------------*/


/** Helper Table **/

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


/*-------------------------------------------------------------------------------------------------*/
/*------------------------------------- DATA FOR DASHBOARD ----------------------------------------*/
/*-------------------------------------------------------------------------------------------------*/


/** Product Table **/

-- Creating Product Table
IF OBJECT_ID('DIM_Product') IS NOT NULL DROP TABLE DIM_Product;

CREATE TABLE DIM_Product (
    ProductID		NVARCHAR(150) UNIQUE NOT NULL,
    ProductName		NVARCHAR(250) UNIQUE NOT NULL,
    Performance		NVARCHAR(50) NOT NULL,
    SubCategory		NVARCHAR(50) NOT NULL,
    Category		NVARCHAR(50) NOT NULL
);

-- Populating Product Table
INSERT INTO DIM_Product(ProductID, ProductName, Performance, SubCategory, Category)

SELECT                                                  -- Creates combined abbrevation of
    CONCAT(                                             -- Category and SubCategory with product 
        UPPER(LEFT(Category, 3)), '-',                  -- number starting at 100,000 and increment by 1
        UPPER(LEFT(SubCategory, 2)), '-',               -- increment reset to 0 for each SubCategory
        CAST(ROW_NUMBER() OVER(PARTITION BY SubCategory ORDER BY Category) + 100000 
    AS NVARCHAR)) AS ProductID,
    ProductName,
    AvgSalesPerformance,
    SubCategory,
    Category
FROM
    #ProductPerformance;


/*-------------------------------------------------------------------------------------------------*/


/** Country Market Table **/

-- Creating Country Table
IF OBJECT_ID('DIM_CountryMarket') IS NOT NULL DROP TABLE DIM_CountryMarket;

CREATE TABLE DIM_CountryMarket(
    CountryID       NVARCHAR(50) NOT NULL,
    CountryName     NVARCHAR(70) UNIQUE NOT NULL,
    Market          NVARCHAR(50) NOT NULL
);

-- Populating Country Market Table
INSERT INTO DIM_CountryMarket(CountryID, CountryName, Market)

SELECT                                                  -- Creates a combine Market name with number
    CAST(                                               -- that starts from 1000 and increment by 1
        CONCAT(UPPER(Market), '-',                      -- reset to 0 for each market region
        ROW_NUMBER() OVER(PARTITION BY Market ORDER BY Country) + 1000) 
    AS NVARCHAR) AS CountryMarketID,
    CY.Country,
    Market
FROM
    (
    SELECT
        DISTINCT Country,
        Market
    FROM
        Stores
    )AS CY


/*-------------------------------------------------------------------------------------------------*/


/** Segment Table **/

-- Creating Segment Table
IF OBJECT_ID('DIM_Segment') IS NOT NULL DROP TABLE DIM_Segment;

CREATE TABLE DIM_Segment(
    SegmentID   TINYINT NOT NULL,
    Segment	    NVARCHAR(30) UNIQUE NOT NULL
);

-- Populating Segment Table
INSERT INTO DIM_Segment(SegmentID, Segment)

SELECT
    ROW_NUMBER() OVER(ORDER BY Segment) AS SegmentID,
    Segment
FROM
    (
    SELECT
        DISTINCT Segment
    FROM
        Stores
    ) AS Seg;


/*-------------------------------------------------------------------------------------------------*/


/** Date Table **/

-- Start and End Dates of the Dataset
SELECT
    MIN(OrderDate) AS StartDate,
    MAX(OrderDate) AS EndDate
FROM
    Stores;

-- Creating Date table
IF OBJECT_ID('DIM_Date') IS NOT NULL DROP TABLE DIM_Date;

CREATE TABLE DIM_Date(
    Date        DATE UNIQUE NOT NULL,
    Day         TINYINT NOT NULL,
    MonthNo     TINYINT NOT NULL,
    MonthName   NVARCHAR(30) NOT NULL,
    QuarterNo   NVARCHAR(30) NOT NULL,
    Year        SMALLINT NOT NULL
);

-- Populating Date Table
DECLARE @StartDate DATE = '2011-01-01';                     -- Dataset Start date
DECLARE @EndDate DATE = '2014-12-31';                       -- Dataset End date
DECLARE @Counter INT = 1;                                   -- Start No. (Day)

WHILE
    @StartDate <= @EndDate                                  -- A Condition, to stop
                                                            -- iteration if met
    BEGIN
        INSERT INTO DIM_Date(Date, Day, MonthNo, MonthName, QuarterNo, Year)

        VALUES
            (
                @StartDate,                                 -- Date 'YYYY-MM-DD'
                DAY(@StartDate),                            -- Date No.
                DATEPART(MM, @StartDate),                   -- Month No.
                LEFT(DATENAME(MONTH, @StartDate), 3),       -- Month Name First 3 letters
                CONCAT('Q',DATEPART(QUARTER, @StartDate)),  -- Quarter No.
                YEAR(@StartDate)                            -- Year No.
            )
        SET @Counter += 1                                   -- Increment by 1
        SET @StartDate = DATEADD(Day, 1, @StartDate)        -- Increment @StartDate by 1
                                                            -- for the next iteration
    END;


/*-------------------------------------------------------------------------------------------------*/


/** Creating Fact Table (Transaction Records) **/

-- Creating Fact table
IF OBJECT_ID('FACT_Sales') IS NOT NULL DROP TABLE FACT_Sales;

CREATE TABLE FACT_Sales(
    OrderDate	DATE NOT NULL,
    SegmentID	TINYINT NOT NULL,
    CountryID	NVARCHAR(50) NOT NULL,
    ProductID	NVARCHAR(150) NOT NULL,
    Sales       DECIMAL(10,2) NOT NULL,
    Quantity	TINYINT NOT NULL,
    Discount	DECIMAL(5,3) NOT NULL,
    Discounted	NVARCHAR(50) NOT NULL,
    Profit      DECIMAL(10,2) NOT NULL

);

-- Populating Fact table
INSERT INTO FACT_Sales(OrderDate, SegmentID, CountryID, ProductID, Sales, Quantity, Discount, Discounted, Profit)

SELECT
    ST.OrderDate,
    --DT.Date,
    --ST.Segment,
    DS.SegmentID,
    --ST.Country,
    DCM.CountryID,
    --ST.ProductName,
    DP.ProductID,
    ST.Sales,
    ST.Quantity,
    ST.Discount,
    CASE
        WHEN Discount > 0.000 THEN 'Yes'
        ELSE 'No'
    END AS IsDiscounted,
    ST.Profit
FROM
    Stores AS ST
        JOIN
    DIM_Date AS DT
    ON ST.OrderDate = DT.Date
        JOIN
    DIM_Segment AS DS
    ON ST.Segment = DS.Segment
        JOIN
    DIM_CountryMarket AS DCM
    ON ST.Country = DCM.CountryName
        JOIN
    DIM_Product AS DP
    ON ST.ProductName = DP.ProductName;