/* ============================================================
    Project: E-Commerce Sales Optimization
    File: 02_exploratory_data_analysis.sql
    Author: Bryan Melvida
   
    Purpose:
    - Analyze demand concentration and regional contribution
    - Identify growth signals and opportunity gaps
    - Evaluate product demand and mix performance
    - Assess pricing and discount sensitivity
    - Examine fulfillment and cost impact on demand
    - Evaluate segment demand and contribution
   ============================================================ */


USE global_store_sales


/* ============================================================
    DEMAND CONCENTRATION & MARKET SHARE CONTRIBUTION
   ------------------------------------------------------------
    - Assess how demand and revenue are distributed across markets
   ============================================================ */

-- Market-level demand concentration metrics
WITH MarketPerformance AS (
    SELECT
        Market,
        COUNT(DISTINCT Country) AS Country_Cnt,
        SUM(Sales) AS Total_Sales,
        COUNT(OrderDate) AS Total_Order,
        SUM(Sales) / NULLIF(COUNT(OrderDate), 0) AS AOV,
        SUM(Sales) / NULLIF(SUM(SUM(Sales)) OVER(),0) AS Sales_Pct
    FROM sales_transaction
    GROUP BY Market
)

-- Metrics for cross-market comparison
SELECT
    Market,
    Country_Cnt AS Country_Coverage,
    FORMAT(Total_Sales / 1e6, 'N2') + ' M' AS Revenue_M,
    FORMAT(Sales_Pct, 'P2') AS Market_Revenue_Pct,
    FORMAT(Total_Order, 'N0') AS Order_Cnt,
    FORMAT(AOV, 'N2') AS AOV,
    FORMAT((Total_Sales / Country_Cnt) / 1e6, 'N2') + ' M' AS 'Country_Revenue(Avg)',
    FORMAT(Total_Order / Country_Cnt, 'N0') AS 'Country_Orders(Avg)'
FROM MarketPerformance
ORDER BY Total_Sales DESC;



/* ------------------------------------------------------------
    Findings
   ------------------------------------------------------------
    - Revenue Concentration:
        - APAC, EU, US, and LATAM collectively account for ~87% of total revenue.
        - Overall performance heavily depends on these four core markets.
    
    - Coverage-Driven Markets:
        - APAC, EU, and LATAM generate revenue across many countries with moderate order volumes.
        - Growth in these markets comes from geographic breadth, not concentrated demand.
    
    - Demand-Dense Market:
        - The US delivers revenue comparable to multi-country markets from a single country.
        - Driven by high order concentration and strong per-country demand.
    
    - Low-Intensity Markets:
        - Africa and EMEA span wide country coverage but contribute limited revenue and orders.
        - Broad presence doesn't translate to meaningful demand.
    
    - Minimal Contributor:
        - Canada contributes minimally to both revenue and order volume.
   ------------------------------------------------------------ */



---------------------------------------------------------------
-- MARKET REVENUE CONCENTRATION ORDER
---------------------------------------------------------------

-- Market ranking reference table
SELECT
    Market,
    ROW_NUMBER() OVER(ORDER BY Total_Sales DESC) AS Rank_Order
INTO #MarketRevenueOrder
FROM (
    SELECT
        Market,
        SUM(Sales) AS Total_Sales
    FROM sales_transaction
    GROUP BY Market
) AS MarketOrder;



/* ============================================================
    PRODUCT DEMAND & MIX PERFORMANCE
   ------------------------------------------------------------
    - Evaluate product-level demand and sales mix contribution
   ============================================================ */

-- Category mix and revenue contribution per market
WITH ProductMix AS (
    SELECT
        Market,
        Category,
        SUM(Sales) AS Total_Sales
    FROM sales_transaction
    GROUP BY
        Market,
        Category
)

-- Rank and percentage share of each category inside its market
SELECT
    PM.Market,
    PM.Category,
    FORMAT(PM.Total_Sales, 'N0') AS Revenue,
    RANK() OVER(PARTITION BY PM.Market ORDER BY PM.Total_Sales DESC) AS Rank_in_Market,
    FORMAT(
        PM.Total_Sales/ NULLIF(SUM(PM.Total_Sales) OVER(PARTITION BY PM.Market), 0),'P2'
    ) AS RevenueShare_in_Market_Pct
FROM ProductMix as PM
JOIN #MarketRevenueOrder AS MRO
    ON PM.Market = MRO.Market
ORDER BY 
    MRO.Rank_Order;




/* ------------------------------------------------------------
    Findings
   ------------------------------------------------------------
    - Category Mix Structure:
    	- Most markets show the top two categories at similar revenue share levels.
    	- The third category drops substantially, with Canada showing the steepest decline.

    - Dominant Category Presence:
        - Technology ranks as the top category in most markets, including APAC, EU, US, EMEA, and Africa.
        - This indicates Technology as the primary revenue driver across regions.

    - Secondary Category Competition:
        - Furniture and Office Supplies compete closely for the second position in most markets.
        - Their relative rank varies by market, but revenue shares are often within a narrow range.

    - Balanced Category Mix (US Positive Outlier):
        - The US shows near-even revenue distribution across all three categories.
        - No single category dominates, reducing reliance on one product line.
   ------------------------------------------------------------ */



/* ============================================================
    PRICING & DISCOUNT SENSITIVITY
   ------------------------------------------------------------
    - Assess customer response to pricing and discount levels
   ============================================================ */

-- Discount level bucketing and market AOV
WITH MarketSensitivity AS (
    SELECT
        Market,
        Discount_Level,
        COUNT(Market) AS Order_Cnt,
        AVG(Sales) AS AOV
    FROM (
        SELECT
            Market,
            CASE
                WHEN Discount > 0.50 THEN 'Aggressive'
                WHEN Discount > 0.25 THEN 'High'
                WHEN Discount > 0.10 THEN 'Medium'
                WHEN Discount > 0 THEN 'Low'
                ELSE 'No-Discount'
            END AS Discount_Level,
            Sales
        FROM sales_transaction
    ) AS DiscountLevels
    GROUP BY
        Market,
        Discount_Level
)     

-- Cross-market discount response metrics
SELECT
    MS.Market,
    MS.Discount_Level,
    FORMAT(MS.Order_Cnt, 'N0') AS Order_Cnt,
    FORMAT(
        CAST(MS.Order_Cnt AS DECIMAL(18,4)) /
        NULLIF(SUM(MS.Order_Cnt) OVER(PARTITION BY MS.Market), 0), 'P2'
    ) AS Order_Pct,
    FORMAT(MS.AOV, 'N0') AS AOV
FROM MarketSensitivity AS MS
JOIN #MarketRevenueOrder AS MRO
    ON MS.Market = MRO.Market
ORDER BY 
    MRO.Rank_Order,
    CASE
        WHEN MS.Discount_Level = 'No-Discount' THEN 1
        WHEN MS.Discount_Level = 'Low' THEN 2
        WHEN MS.Discount_Level = 'Medium' THEN 3
        WHEN MS.Discount_Level = 'High' THEN 4
        WHEN MS.Discount_Level = 'Aggressive' THEN 5
    END;


/* ------------------------------------------------------------
    Findings
   ------------------------------------------------------------
    - Core Markets Are Demand-Led (APAC, EU, US, LATAM):
        - 67% to 86% of all orders occur at Medium or lower discount levels.
        - AOV remains stable or peaks in Low/Moderate levels, not in heavy discount levels.
        - High discounts lead to lower order spend, not premium order growth.
        - Aggressive discounts represent a minor share of orders (0.4% to 8.5% depending on market).

    - Split Price-Driven Buyers (EMEA & Africa):
        - Majority of orders transact at No-Discount (67%–77%) with normal AOV ranges (199–202).
        - A large secondary segment only buys at Aggressive discounts (22%–32%) with low AOV (58–78).

    - Canada — Small Full-Price Niche Market:
        - 100% of orders occur at No-Discount.
   ------------------------------------------------------------ */



/* ============================================================
    FULFILLMENT & COST IMPACT ON DEMAND
   ------------------------------------------------------------
    - Examine how fulfillment cost and operational factors
      influence demand
   ============================================================ */

-- Ship mode delivery records
WITH ShippingDetails AS (
    SELECT
        ShipMode,
        ShippingCost,
        Quantity,
        Sales,
        DATEDIFF(DAY, OrderDate, ShipDate) AS Delivery_Days
    FROM sales_transaction
)

-- Ship mode metric aggregation
, ShippingMetrics AS (
    SELECT
        ShipMode,
        COUNT(*) AS Order_Cnt,
        AVG(ShippingCost) AS ShipCost_Avg,
        AVG(Quantity) AS Quantity_Avg,
        SUM(Quantity) AS Total_Quantity,
        AVG(Sales) AS Sales_Avg,
        SUM(Sales) AS Total_Sales,
        MIN(Delivery_Days) AS DeliveryDays_Min,
        AVG(Delivery_Days) AS DeliveryDays_Avg,
        MAX(Delivery_Days) AS DeliveryDays_Max
    FROM ShippingDetails
    GROUP BY ShipMode
    )

-- Ship mode performance metrics
SELECT
    Shipmode,
    DeliveryDays_Min,
    DeliveryDays_Avg,
    DeliveryDays_Max,
    FORMAT(Order_Cnt, 'N0') AS Order_Cnt,
    FORMAT(
        CAST(Order_Cnt AS FLOAT) / NULLIF(SUM(Order_Cnt) OVER(), 0),'P2'
    ) AS Order_Pct,
    FORMAT(ShipCost_Avg, 'N0') AS ShipCost_Avg,
    Quantity_Avg,
    FORMAT(Total_Quantity, 'N0') AS Total_Quantity,
    FORMAT(
        CAST(Total_Quantity AS FLOAT) / NULLIF(SUM(Total_Quantity) OVER(), 0), 'P2'
    ) AS Total_Quantity_Pct,
    FORMAT(Sales_Avg, 'N0') AS Sales_Avg,
    FORMAT(Total_Sales, 'N0') AS Total_Sales,
    FORMAT(
        Total_Sales / NULLIF(SUM(Total_Sales) OVER(), 0), 'P2'
    ) AS Total_Sales_Pct
FROM ShippingMetrics
ORDER BY
    CASE 
        WHEN Shipmode = 'Same Day' THEN 1
        WHEN Shipmode = 'First Class' THEN 2
        WHEN Shipmode = 'Second Class' THEN 3
        ELSE 4
    END;



/* ------------------------------------------------------------
    Findings
   ------------------------------------------------------------
    -  Shipping Preference Is Cost-Led, Not Urgency-Led:
      – 80% of all orders use slower, economy-focused shipping modes: 60% Standard Class and 20% Second Class

    - Delivery Speed Does Not Influence Order Size or Spend:
      – Average order value (244–249 AOV) and average order quantity (3 units) remain consistent across all ship modes

    - Economy Modes Fall Within a 3–7 Day Delivery Window:
      – Second Class and Standard Class deliver in 3–4 days on average, while Standard Class extends to 7 days at maximum
   ------------------------------------------------------------ */



/* ============================================================
    Segment Contribution & Demand Quality
   ------------------------------------------------------------
    - Assess how demand and revenue are distributed across segments
   ============================================================ */


SELECT
    segment,
    SUM(sales) AS total_sales,
    SUM(quantity) AS total_quantity

FROM sales_transaction
GROUP BY segment

/* ------------------------------------------------------------
    Findings
   ------------------------------------------------------------
    - Short Summary Findings
   ------------------------------------------------------------ */


/* ============================================================
    END OF EXPLORATORY DATA ANALYSIS SCRIPT
   ============================================================ */