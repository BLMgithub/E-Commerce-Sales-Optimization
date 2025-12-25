/* ============================================================
    Project: E-Commerce Sales Optimization
    File: 01_Data_Cleaning.sql
    Author: Bryan Melvida
   
    Purpose:
    - Ingest raw transactional data
    - Assess data quality, consistency, and anomalies
    - Apply targeted data corrections prior to analysis

    DATA NOTES:
    - Source: Global-Superstore.csv
   ============================================================ */


USE Super_Store;


/* ============================================================
    RAW DATA INGESTION
   ------------------------------------------------------------
    - Create a staging table to store raw data
   ============================================================ */


IF OBJECT_ID('Stores') IS NOT NULL DROP TABLE Stores;

CREATE TABLE Stores (
    RowID           INT NULL,
    OrderID         NVARCHAR(70) NULL,
    OrderDate       DATE NULL,
    Shipdate        DATE NULL,
    Shipmode        NVARCHAR(30) NULL,
    CustomerID      NVARCHAR(30) NULL,
    CustomerName    NVARCHAR(70) NULL,
    Segment         NVARCHAR(30) NULL,
    City            NVARCHAR(100) NULL,
    State           NVARCHAR(100) NULL,
    Country         NVARCHAR(100) NULL,
    Market          NVARCHAR(30) NULL,
    Region          NVARCHAR(30) NULL,
    ProductID       NVARCHAR(100) NULL,
    Category        NVARCHAR(30) NULL,
    SubCategory     NVARCHAR(30) NULL,
    ProductName     NVARCHAR(255) NULL,
    Sales           DECIMAL(10,2) NULL,
    Quantity        TINYINT NULL,
    Discount        DECIMAL(5,3) NULL,
    Profit          DECIMAL(10,2) NULL,
    ShippingCost    Decimal(10,2) NULL,
    OrderPriority   NVARCHAR(30) NULL
    );


/* ============================================================
    DATA LOAD
   ------------------------------------------------------------
    - Import raw CSV data into the staging table
   ============================================================ */


BULK INSERT Stores
FROM 'E:\E-Commerce-Sales-Optimization\data\raw\Global-Superstore.csv'
WITH (
    FORMAT= 'CSV',
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n'
    );


-- Verification
SELECT TOP 10 *
FROM Stores
ORDER BY NEWID();


/* ============================================================
    DATA PROFILING & STRUCTURE AUDIT
   ------------------------------------------------------------
    - Understand column-level completeness and uniqueness
    - Identify early red flags before deeper analysis
   ============================================================ */


IF OBJECT_ID('tempdb..#DataInfo') IS NOT NULL DROP TABLE #DataInfo;

CREATE TABLE #DataInfo(
    ColumnName      NVARCHAR(100),
    DataType        NVARCHAR(30),
    NullCount       INT,
    DistinctCount   INT
);

DECLARE @GetNulls_DistinctCount NVARCHAR(MAX);

SELECT @GetNulls_DistinctCount = 
    'INSERT INTO #DataInfo ' +
    
    STRING_AGG(
        CAST(
            'SELECT 
                ''' + name + ''' AS ColumnName,
                '''+ DATA_TYPE +''' As DataType,
                COUNT(CASE WHEN ' + name + ' IS NULL THEN 1 END) AS NullCount,
                COUNT(DISTINCT ' + name +') AS DistinctCount
             FROM Stores'
                AS NVARCHAR(MAX)), -- Prevents STRING_AGG error (8,000-byte limit)
            ' UNION ALL '
            )
FROM sys.columns AS Syscol
JOIN INFORMATION_SCHEMA.Columns as InfoCol
    ON Syscol.name = InfoCol.COLUMN_NAME
WHERE object_id = OBJECT_ID('Stores')
    AND TABLE_NAME = 'Stores';

EXEC(@GetNulls_DistinctCount);


-- Verification
SELECT *
FROM #DataInfo;


/* ============================================================
    DUPLICATE & KEY CONSISTENCY CHECKS
   ------------------------------------------------------------
    - Detect duplicate records
    - Validate ID to name relationships
   ============================================================ */


DECLARE @GetDuplicates NVARCHAR(MAX);

SELECT @GetDuplicates =
    'SELECT 
        COUNT(*) AS DuplicateCounter,
        ' + STRING_AGG(QUOTENAME(name), ', ') + '
    FROM Stores 
    GROUP BY
        ' + STRING_AGG(QUOTENAME(name), ', ') + '
    HAVING COUNT(*) > 1'

FROM sys.columns
WHERE object_id = OBJECT_ID('Stores');

EXEC(@GetDuplicates);


-- CustomerID to CustomerName consistency
SELECT
    COUNT(DISTINCT CustomerName) AS Customer_DistinctCnt,
    COUNT(DISTINCT CustomerID) AS CustomerID_DistinctCnt
FROM Stores;

-- ProductID to ProductName consistency
SELECT
    COUNT(DISTINCT ProductName) AS Product_DistinctCnt,
    COUNT(DISTINCT ProductID) AS ProductID_DistinctCnt
FROM Stores;


/* ------------------------------------------------------------
    Findings
   ------------------------------------------------------------
    - CustomerID to CustomerName mismatches: 795 records
    - ProductID to ProductName mismataches: 6,504 records
   ------------------------------------------------------------ */



/* ============================================================
    HIERARCHY & DIMENSION VALIDATION
   ------------------------------------------------------------
    - Validate Market to Country Relationships
    - Validate Category to SubCategory to Product Hierarchies
   ============================================================ */


-- Market to Country coverage
SELECT
    Market,
    COUNT(DISTINCT Country) AS Country_Cnt
FROM Stores
GROUP BY Market;

-- Market to Country hierarchy consistency check
SELECT
    COUNT(DISTINCT Country) AS Country_DistinctCnt,
    COUNT(DISTINCT CONCAT(Market,Country)) AS MarketCountry_MapCnt
FROM Stores;


-- Category to SubCategory coverage
SELECT
    Category,
    COUNT(DISTINCT SubCategory) AS SubCategory_Cnt
FROM Stores
GROUP BY Category;

-- Category to SubCategory hierarchy consistency check
SELECT
    COUNT(DISTINCT SubCategory) AS SubCat_DistinctCnt,
    COUNT(DISTINCT CONCAT(Category, SubCategory)) AS CategorySubCat_MapCnt
FROM Stores;


-- SubCategory to Product coverage
SELECT
    Category,
    SubCategory,
    COUNT(DISTINCT ProductName) AS ProductName_Cnt
FROM Stores
GROUP BY 
    Category,
    SubCategory
ORDER BY 
    Category,
    ProductName_Cnt DESC;

-- SubCategory to Product hierarchy consistency check
SELECT
    COUNT(DISTINCT ProductName) AS Product_DistinctCnt,
    COUNT(DISTINCT CONCAT(SubCategory, ProductName)) AS SubCatProduct_MapCnt
FROM Stores;


/* ------------------------------------------------------------
    Findings
   ------------------------------------------------------------
    - Market to Country hierarchy inconsistency:
      149 Market–Country combinations across 147 countries
    - SubCategory to Product hierarchy inconsistency:
      3,797 Sub-Category–Product combinations across 3,788 products
   ------------------------------------------------------------ */



/* ============================================================
    CONTINUOUS VARIABLE VALIDATION
   ------------------------------------------------------------
    - Validate numeric ranges
   ============================================================ */


-- Identify continuous fields for range validation
SELECT *
FROM #DataInfo
WHERE DataType != 'nvarchar';

-- Temporarly store Continuous Variables for range analysis
SELECT ColumnName
INTO #ContinuousVariables
FROM #DataInfo
WHERE ColumnName IN ('Sales','Quantity','Discount','Profit','ShippingCost');

-- Calculate Min, Avg, and  Max values for continuous variables
DECLARE @GetMinMax NVARCHAR(MAX);

SELECT @GetMinMax =
    STRING_AGG(
        'SELECT ''' + name + ''' AS ColumnName,
                MIN(' + name + ') AS MinValue,
                AVG(' + name + ') AS AvgValue,
                MAX(' + name + ') AS MaxValue
         FROM Stores',
        ' UNION ALL '
    )
FROM sys.columns
JOIN #ContinuousVariables
  ON name = ColumnName
WHERE object_id = OBJECT_ID('Stores');

EXEC(@GetMinMax);


/* ------------------------------------------------------------
    Findings
   ------------------------------------------------------------
    - Profit shows extreme negative values relative to sales
      (-6,599.98 vs minimum sales of 0.44)
    - Loss magnitudes suggest potential data or calculation issues
   ------------------------------------------------------------ */


/* ============================================================
    DATA QUALITY CORRECTIONS
   ------------------------------------------------------------
    - Resolve Market to Country hierarchy issues
    - Resolve SubCategory to Product hierarchy issues
   ============================================================ */


---------------------------------------------------------------
-- Market to Country Hierarchy Corrections
---------------------------------------------------------------

-- Identify countries mapped to more than one market
SELECT
    Country,
    COUNT(DISTINCT Market) AS Market_DistinctCount
FROM Stores
GROUP BY
    Country
HAVING
    COUNT(DISTINCT Market) > 1;

-- Review affected Market–Country combinations
SELECT
    Country,
    Market
FROM Stores
WHERE Country IN ('Austria', 'Mongolia')
GROUP BY
    Country,
    Market;

-- Prepare corrected Market mapping
SELECT
    RowID,
    CASE
        WHEN Country = 'Austria'  THEN 'EU'
        WHEN Country = 'Mongolia' THEN 'APAC'
    END AS CorrectMarket
INTO #ToChangeMarketCountry
FROM Stores
WHERE
    Market = 'EMEA'
    AND Country IN ('Austria','Mongolia');

-- Apply Market to Country hierarchy corrections
BEGIN TRAN;

UPDATE ST
SET
    Market = MC.CorrectMarket
FROM Stores AS ST
JOIN #ToChangeMarketCountry AS MC
    ON ST.RowID = MC.RowID;

-- COMMIT;



---------------------------------------------------------------
-- SubCategory to Product Hierarchy Corrections
---------------------------------------------------------------

-- Identify products mapped to multiple SubCategories
WITH Duplicates AS (
    SELECT
        ProductName,
        COUNT(DISTINCT SubCategory) AS SubCat_DistinctCnt
    FROM Stores
    GROUP BY
        ProductName
)
SELECT
    ST.Category,
    ST.SubCategory,
    ST.ProductName
FROM Stores AS ST
JOIN Duplicates AS DU
    ON ST.ProductName = DU.ProductName
WHERE
    DU.SubCat_DistinctCnt > 1
GROUP BY
    ST.Category,
    ST.SubCategory,
    ST.ProductName;

-- Prepare corrected SubCategory and Category mapping
SELECT
    RowID,
    SubCategory,
    ProductName,
    'Fasteners'        AS CorrectSubCategory,
    'Office Supplies'  AS CorrectCategory
INTO #ToChangeSubCategoryProductName
FROM Stores
WHERE
    ProductName = 'Staples'
    AND SubCategory != 'Fasteners';

-- Apply SubCategory to Product hierarchy corrections
BEGIN TRAN;

UPDATE ST
SET
    SubCategory = SP.CorrectSubCategory,
    Category    = SP.CorrectCategory
FROM Stores AS ST
JOIN #ToChangeSubCategoryProductName AS SP
    ON SP.RowID = ST.RowID;

-- COMMIT;




/* ============================================================
    DATA HANDLING DECISION
   ------------------------------------------------------------
    - Handle CustomerID to CustomerName inconsistencies
    - Handle ProductID to ProductName inconsistencies
    - Handle suspicious Negative Profit records
   ============================================================ */


---------------------------------------------------------------
-- CustomerID to CustomerName Inconsistencies Corrections
---------------------------------------------------------------

-- Identify CustomerNames mapped to multiple CustomerIDs and multiple Regions
SELECT
    CustomerName,
    COUNT(DISTINCT CustomerID) AS CustomerID_DistinctCnt,
    COUNT(DISTINCT Region) AS CustomerRegion_DistinctCnt
FROM Stores
GROUP BY CustomerName;



---------------------------------------------------------------
-- ProductID to ProductName Inconsistencies Corrections
---------------------------------------------------------------

-- Identify ProductNames mapped to multiple ProductIDs
SELECT
    ProductName,
    COUNT(DISTINCT ProductID) AS ProductID_DistinctCnt
FROM Stores
GROUP BY ProductName
HAVING COUNT(DISTINCT ProductID) > 1;


---------------------------------------------------------------
-- Suspicious Negative Profit Handling
---------------------------------------------------------------

-- Identify Records with Negative Profit
SELECT *
FROM Stores
WHERE Profit < 0
ORDER BY Profit ASC;


-- Assess magnitude and persistence of negative Profit
WITH NegativeProfit AS (
    SELECT 
        YEAR(OrderDate) as OrderYear,
        SUM(Profit) AS NegativeProfit
    FROM Stores
    WHERE Profit < 0
    GROUP BY YEAR(OrderDate)
),
PositiveProfit AS (
    SELECT 
        YEAR(OrderDate) as OrderYear, 
        SUM(Profit) AS PositiveProfit
    FROM Stores
    WHERE Profit > 0
    GROUP BY YEAR(OrderDate)
)
SELECT
    NP.OrderYear,
    FORMAT(NP.NegativeProfit, 'N0') AS NegativeProfit,
    FORMAT(PP.PositiveProfit, 'N0') AS PositiveProfit,
    FORMAT(ABS(NP.NegativeProfit) / PP.PositiveProfit, 'P2')
        AS NegativeToPositiveRatio
FROM NegativeProfit NP
JOIN PositiveProfit PP
  ON NP.OrderYear = PP.OrderYear
ORDER BY NP.OrderYear;



/* ============================================================
    DATA HANDLING DECISION
   ------------------------------------------------------------
    - CustomerName excluded due to non-unique CustomerID mapping
    - ProductID ignored; ProductName retained for analysis
    - Profit excluded from KPI analysis due to unexplained
      extreme and persistent negative values
   ============================================================ */


/* ============================================================
    END OF DATA CLEANING SCRIPT
   ============================================================ */