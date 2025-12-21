
USE Super_Store

/*-------------------------------------------------------------------------------------------------*/
/*----------------------------- CREATING TABLE TO STORE RAW DATA ----------------------------------*/
/*-------------------------------------------------------------------------------------------------*/


IF OBJECT_ID('Stores') IS NOT NULL DROP TABLE Stores;

CREATE TABLE Stores(
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


/*-------------------------------------------------------------------------------------------------*/
/*------------------------------------ IMPORTING DATA ---------------------------------------------*/
/*-------------------------------------------------------------------------------------------------*/


BULK INSERT Stores

FROM
    'D:\_Projects\2025_Project_2_Super_Store\Data\Global-Superstore.csv'

WITH (
    FORMAT= 'CSV',
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n'
    );


-- Checking Result 
SELECT
    TOP 10 *
FROM
    Stores;


/*-------------------------------------------------------------------------------------------------*/
/*-------------------------------------- DATA INSPECTION ------------------------------------------*/
/*-------------------------------------------------------------------------------------------------*/


/**  Creating Dataset Information  **/

-- Creating Summary Table
IF OBJECT_ID('#DataInfo') IS NOT NULL DROP TABLE #DataInfo;

CREATE TABLE #DataInfo(
    ColumnName      NVARCHAR(100),
    DataType        NVARCHAR(30),
    NullCount       INT,
    DistinctCount   INT
);

-- Store String Query
DECLARE @GetNulls_DistinctCount NVARCHAR(MAX);

-- Constructing Query
SELECT @GetNulls_DistinctCount = 
    
    'INSERT INTO #DataInfo ' +
    
    STRING_AGG(
        CAST('SELECT 
                ''' + name + ''' AS ColumnName,
                '''+ DATA_TYPE +''' As DataType,
                COUNT(CASE WHEN ' + name + ' IS NULL THEN 1 END) AS NullCount,
                COUNT(DISTINCT ' + name +') AS DistinctCount
            FROM
                Stores'
                AS NVARCHAR(MAX)        -- Bypass 8000-byte limit on STRING_AGG  
                ),
            ' UNION ALL ' 
            )
FROM
    sys.columns AS Syscol
        JOIN
    INFORMATION_SCHEMA.Columns as InfoCol
    ON Syscol.name = InfoCol.COLUMN_NAME
WHERE
    object_id = OBJECT_ID('Stores')
        AND
    TABLE_NAME = 'Stores';

-- Executing Stored Query
EXEC(@GetNulls_DistinctCount);


-- Checking Result
SELECT
    *
FROM
    #DataInfo


/*-------------------------------------------------------------------------------------------------*/


/** Checking Duplicates on dataset **/

-- Store String Query
DECLARE @GetDuplicates NVARCHAR(MAX);

-- Constructing Query
SELECT @GetDuplicates =
    'SELECT 
        COUNT(*) AS DuplicateCounter,
        ' + STRING_AGG(QUOTENAME(name), ', ') + '
    FROM 
        Stores 
    GROUP BY
        ' + STRING_AGG(QUOTENAME(name), ', ') + '
    HAVING
        COUNT(*) > 1'
FROM
	sys.columns
WHERE
	object_id = OBJECT_ID('Stores');

-- Executing Stored Query
EXEC(@GetDuplicates);


/*-------------------------------------------------------------------------------------------------*/


/**  Checking Data Consistency for CustomerID and CustomerName (TO DROP: Mismatch Count)  **/
SELECT
    COUNT(DISTINCT(CustomerName)) AS UniqueCustomer,
    COUNT(DISTINCT(CustomerID)) AS UniqueCustomerID
FROM
    Stores;


/*-------------------------------------------------------------------------------------------------*/


/**  Checking Data Consistency for ProductID and ProductName (TO DROP: Mismatch Count)	 **/
SELECT
    COUNT(DISTINCT(ProductName)) AS UniqueProduct,
    COUNT(DISTINCT(ProductID)) AS UniqueProductID
FROM
    Stores;


/*-------------------------------------------------------------------------------------------------*/


/** Checking Country count for each market (TO FIX: combine US and Canada into NA 'NorthAmerica') **/
SELECT
    Market,
    COUNT(DISTINCT Country) AS CountryCount
FROM
    Stores
GROUP BY
    Market;


/*-------------------------------------------------------------------------------------------------*/


/**  Checking Market & Country Hierarchy (TO FIX: Inconsistentcy)  **/
SELECT
    COUNT(DISTINCT(Country)) AS UniqueCountry,
    (
    SELECT
        COUNT(DISTINCT(MC.MarketCountry))               -- Unique Count of Market &
    FROM (                                              -- Country Combination
        SELECT											
            CONCAT(Market, Country) AS MarketCountry    -- Stores combined Market & Country
        FROM
            Stores
        GROUP BY
            Market,
            Country
        ) AS MC
    ) AS UniqueMarketCountry                            -- Result Column Name
FROM
    Stores;


/*-------------------------------------------------------------------------------------------------*/


/** Checking SubCategory count for each Category  **/
SELECT
    *
FROM
    #DataInfo;

--

SELECT
    Category,
    COUNT(DISTINCT SubCategory) AS SubCategoryCount
FROM
    Stores
GROUP BY
    Category;


/*-------------------------------------------------------------------------------------------------*/


/**  Checking Category & SubCategory Hierachy  **/
SELECT
    COUNT(DISTINCT(SubCategory)) AS UniqueSubCategory,
    (
    SELECT
        COUNT(DISTINCT(CS.CategorySubcategory))                     -- Unique Count of Category &
    FROM (                                                          -- SubCategory Combination
        SELECT
            CONCAT(Category, SubCategory) AS CategorySubcategory    -- Stores combined 
        FROM                                                        -- Category & SubCategory
            Stores
        GROUP BY
            Category,
            SubCategory
        ) AS CS
    ) AS UniqueCategorySubcategory                                  -- Result Column Name
FROM
    Stores;


/*-------------------------------------------------------------------------------------------------*/


/** Checking Product count for each SubCategory  **/
SELECT
    Category,
    SubCategory,
    COUNT(DISTINCT ProductName) AS ProductNameCount
FROM
    Stores
GROUP BY
    Category,
    SubCategory
ORDER BY
    Category,
    ProductNameCount DESC;


/*-------------------------------------------------------------------------------------------------*/


/**  Checking SubCategory & ProductName Hierarchy (TO FIX: Inconsistency)  **/
SELECT
    COUNT(DISTINCT(ProductName)) AS UniqueProduct,
    (
    SELECT
        COUNT(DISTINCT(SP.SubcategoryProduct))                      -- Unique Count of Combined
    FROM (                                                          -- SubCategory & ProductName
        SELECT
            CONCAT(SubCategory, ProductName) AS SubcategoryProduct  -- Stores combined
        FROM                                                        -- SubCategory & ProductName
            Stores
        GROUP BY
            SubCategory,
            ProductName
        ) AS SP
    ) AS UniqueSubcategoryProduct                                   -- Result Column Name
FROM
    Stores;


/*-------------------------------------------------------------------------------------------------*/


/** Cheking Continuous Variables **/
SELECT
    *
FROM
    #DataInfo
WHERE
    DataType != 'Nvarchar';

-- Creating Temporary table for Continuous variable

SELECT
    ColumnName
INTO #ContinuousVariables
FROM
    #DataInfo
WHERE
    ColumnName IN ('Sales', 'Quantity', 'Discount', 'Profit', 'ShippingCost');


/** Cheking Range of Continuous Variables **/

-- Storing String Query
DECLARE @GetMinMax NVARCHAR(MAX);

-- Constructing Query
SELECT @GetMinMax = 
    
    STRING_AGG(
            ('SELECT 
                ''' + name + ''' AS ColumnName,
                MIN('+ name + ') AS MinValue,
                MAX(' + name +') AS MaxValue
            FROM
                Stores'
                ),
            ' UNION ALL ' 
            )
FROM
    sys.columns AS SysCol
        RIGHT JOIN
    #ContinuousVariables AS ContVar
    ON SysCol.name = ContVar.ColumnName

WHERE
    object_id = OBJECT_ID('Stores')

-- Executing Stored Query
EXEC(@GetMinMax);


/*-------------------------------------------------------------------------------------------------*/


/** Checking Suspicious Values **/

SELECT
    *
FROM
    Stores
WHERE
    Sales = 22638.480

--

SELECT
    *
FROM
    Stores
WHERE
    Profit IN(-6599.980, 8399.980)

--

SELECT
    *
FROM
    #DataInfo

/*-------------------------------------------------------------------------------------------------*/


/** Checking on negative profit values **/

SELECT
    *
FROM
    Stores
WHERE
    Profit < 0
ORDER BY
    Profit ASC;


/*-------------------------------------------------------------------------------------------------*/


/** Calculating Negative to Positve Profit ratio **/

WITH NegativeProfit AS (
        SELECT
            Year,
            SUM(Profit) AS NegativeProfit
        FROM
            Stores
        WHERE
            Profit < 0
        GROUP BY
            Year
),
    PositiveProfit AS (
        SELECT
            Year,
            SUM(Profit) AS PositiveProfit
        FROM
            Stores
        WHERE
            Profit > 0
        GROUP BY
            Year
)
SELECT
    NP.Year,
    FORMAT(NP.NegativeProfit, 'N0') AS NegativeProfit,
    FORMAT(PP.PositiveProfit, 'N0') AS PositiveProfit,
    FORMAT(ABS(NP.NegativeProfit)/PP.PositiveProfit, 'P2') AS NegativeToPositiveRatio
FROM
    NegativeProfit AS NP
        JOIN
    PositiveProfit AS PP
    ON NP.Year = PP.Year
ORDER BY
    NP.Year;


/*-------------------------------------------------------------------------------------------------*/


/** Identifying which categories contribute the most to cumulative negative profit over time **/

SELECT
    Year,
    Category,
    FORMAT(SUM(Profit), 'N0') AS NegativeProfit,
    FORMAT(
        SUM(Profit) + LAG(SUM(Profit)) OVER(PARTITION BY Category ORDER BY Year)
        , 'N0') AS YearlyIncreaseProfitLoss 
FROM
    Stores
WHERE
    Profit < 0
GROUP BY
    Year,
    Category
ORDER BY
    Category,
    Year;


/*-------------------------------------------------------------------------------------------------*/


/** Identifying which Markets and Segments contribute the most to negative profit transactions **/

WITH NegativeProfitMarketSegment AS (
    SELECT
        Market,
        Segment,
        SUM(Profit) AS TotalNegativeProfit,
        COUNT(Profit) AS TotalOrders
    FROM
        Stores
    WHERE
        Profit < 0
    GROUP BY
        Market,
        Segment
)
SELECT
    Market,
    Segment,
    DENSE_RANK() OVER(PARTITION BY Market ORDER BY TotalNegativeProfit) AS SegmentRank,
    FORMAT(TotalNegativeProfit, 'N0') AS TotalNegativeProfit,
    FORMAT(TotalOrders, 'N0') AS TotalOrder
FROM
    NegativeProfitMarketSegment
ORDER BY
    Market,
    SegmentRank;


/*-------------------------------------------------------------------------------------------------*/

/** Breaking down negative profit by shipping mode to uncover patterns or potential refund behavior **/

SELECT
    Shipmode,
    FORMAT(COUNT(OrderID),'N0') AS TotalOrders,
    FORMAT(SUM(Profit), 'N0') AS NegativeProfit,
    FORMAT(SUM(profit) / ( SUM(profit)
                            + (
                                SELECT 
                                    SUM(profit)
                                FROM
                                    stores
                                WHERE  
                                    profit < 0
                                    ) 
                                ), 'P2') AS Portion
FROM
    Stores
WHERE
    Profit < 0
GROUP BY
    Shipmode
ORDER BY
    SUM(Profit);


/*-------------------------------------------------------------------------------------------------*/


/** Creating a list of random OrderIDs to inspect and verify conclusion **/

SELECT
    OrderID,
    COUNT(OrderID) AS TotalOrders,
    SUM(Profit) AS TotalProfit
FROM
    Stores
WHERE
    Shipmode = 'Standard Class'
GROUP BY
    OrderID
ORDER BY
    SUM(Profit);


/*-------------------------------------------------------------------------------------------------*/


/** Inspecting random OrderIDs **/

SELECT
    OrderDate,
    OrderID,
    Sales,
    Discount,
    Quantity,
    FORMAT(Sales * Discount, 'N2') AS DiscountValue,
    FORMAT(Sales - (Sales * Discount), 'N2') AS NetRevenue,
    Profit,
    CASE
        WHEN Profit <0 THEN '-'
        ELSE '+'
    END AS 'ProfitFlag'
FROM
    Stores
WHERE
    OrderID IN('CA-2013-108196', 'CA-2011-169019', 'CA-2014-134845',
                'TU-2011-6790', 'CA-2013-130946', 'CA-2014-151750')     -- Random Selection
ORDER BY
    OrderID,
    Profit;

/*

Deep diving into negative profit revealed extreme cases where negative profit exceeds total sales value.

Which logically shouldn't happen. Is likely result from one or more of the following:

1. System glitches or data quality issues leading to invalid profit entries.
2. Double-counting discounts or misapplied business logic in ETL/Profit calculation.
3. As this is dummy data, the issue might stems from random value generation in the profit column.

*/



/*-------------------------------------------------------------------------------------------------*/
/*--------------------------------------- DATA CLEANING -------------------------------------------*/
/*-------------------------------------------------------------------------------------------------*/


/**  Fix for Combining US and Canada into 1 Market 'NorthAmerica' **/
BEGIN TRAN
UPDATE
    Stores
    SET Market=
        'NA'
    FROM
        Stores
    WHERE
        Market IN ('US', 'Canada');

-- ROLLBACK;
-- COMMIT;


/*-------------------------------------------------------------------------------------------------*/


/**  Fix for Market & Country Hierarchy Inconsistency  **/

--  Identifying Inconsistency
WITH Duplicates AS(
    SELECT
        MC.Country,
        COUNT(MC.Country) AS UniqueCount            -- Counts Unique Country (Serves as Flag)
        FROM (
            SELECT                                  -- Stores combined Market & Country
                Market, 
                Country
            FROM
                Stores
            GROUP BY
                Market,
                Country
            ) AS MC
    GROUP BY
        MC.Country
)
SELECT
    ST.Market,
    ST.Country,
    COUNT(ST.Country) AS RegCount
FROM
    Stores AS ST
        JOIN
    Duplicates AS DU
    ON ST.Country = DU.Country
WHERE
    DU.UniqueCount > 1                              -- Return data with more than 1 unique count
GROUP BY
    ST.Market,
    ST.Country;


/*-------------------------------------------------------------------------------------------------*/


-- Assigning Correct Value, to be map for each Associated RowID in Update Statement
SELECT
    RowID,
    Market,
    Country,
    CASE
        WHEN Market = 'EMEA' AND Country = 'Austria' THEN 'EU'
        WHEN Market = 'EMEA' AND Country = 'Mongolia' THEN 'APAC'
    END AS CorrectMarket
INTO #ToChangeMarketCountry                         -- Saved Into Temporary Table
FROM
    Stores
WHERE
    Market = 'EMEA' AND Country = 'Austria'	
    OR Market = 'EMEA' AND Country = 'Mongolia';


/*-------------------------------------------------------------------------------------------------*/


-- Mapping Correct 'Market' for identified inconsistent data.
BEGIN TRAN
UPDATE
    Stores
    SET Market =
        CASE
            WHEN MC.RowID = ST.RowID THEN MC.CorrectMarket
        END
    FROM
        Stores AS ST
            LEFT JOIN
        #ToChangeMarketCountry AS MC
        ON MC.RowID = ST.RowID
    WHERE
        MC.RowID = ST.RowID;                                  -- Only matching RowID will be
                                                              -- affected by the update
-- ROLLBACK;
-- COMMIT;


/*-------------------------------------------------------------------------------------------------*/


/**  Fix for SubCategory & ProductName Hierarchy Inconsistency  **/

--  Identifying Inconsistency
WITH Duplicates AS(
    SELECT
        SP.ProductName,
        COUNT(SP.ProductName) AS UniqueCount                -- Count Unique ProductName (Servers as Flag)
        FROM (
            SELECT                                          -- Stores combined SubCategory 
                SubCategory,                                -- & ProductName
                ProductName
            FROM
                Stores
            GROUP BY
                SubCategory, 
                ProductName
            ) AS SP
    GROUP BY
        SP.ProductName
)
SELECT
    ST.Category,
    ST.SubCategory,
    ST.ProductName,
    COUNT(ST.ProductName) AS RegCount
FROM
    Stores AS ST
        JOIN
    Duplicates AS DU								
    ON ST.ProductName = DU.ProductName
WHERE
    DU.UniqueCount > 1                                      -- Return data with more than 1 unique count
GROUP BY
    ST.Category,
    ST.SubCategory,
    ST.ProductName;


/*-------------------------------------------------------------------------------------------------*/


-- Assigning Correct Value, to be map for each Associated RowID in Update Statement
SELECT
    RowID,
    SubCategory,
    ProductName,
    'Fasteners' AS CorrectSubCategory,
    'Office Supplies' AS CorrectCategory
INTO #ToChangeSubCategoryProductName                        -- Saved into Temporary Table
FROM
    Stores
WHERE
    SubCategory != 'Fasteners' AND ProductName = 'Staples';


/*-------------------------------------------------------------------------------------------------*/


-- Mapping Correct 'SubCategory' for identified inconsistent data
BEGIN TRAN
UPDATE
    Stores
    SET SubCategory =
        CASE
            WHEN SP.RowID = ST.RowID THEN SP.CorrectSubCategory     -- Maps Correct Values
        END,
    Category =
        CASE
            WHEN SP.RowID = ST.RowID THEN SP.CorrectCategory
        END
    FROM
        Stores AS ST
            LEFT JOIN
        #ToChangeSubCategoryProductName AS SP
        ON SP.RowID = ST.RowID
    WHERE
        SP.RowID = ST.RowID;                                        -- Only matching RowID will be
                                                                    -- affected by the update
 --ROLLBACK;
-- COMMIT;

