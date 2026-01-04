/* ============================================================
    Project: E-Commerce Sales Optimization
    File: 02_exploratory_data_analysis.sql
    Author: Bryan Melvida
   
    Purpose:
    - Understand demand concentration and market-level growth relevance
    - Surface structural growth signals and opportunity gaps
    - Assess product demand mix and category concentration
    - Evaluate discount sensitivity and demand quality by market
    - Understand fulfillment cost relationships and shipping demand mix
    - Assess segment-level demand contribution
   ============================================================ */


USE global_store_sales


---------------------------------------------------------------
-- SNAPSHOT TABLE FOR ANALYTICAL REUSE
---------------------------------------------------------------

SELECT
    market,
    country,
    sales,
    discount,
    category,
    ship_mode,
    order_date,
    ship_date,
    shipping_cost,
    segment
INTO #stg_sales_analysis
FROM sales_transaction;



/* ============================================================
    MARKET DEMAND CONCENTRATION & GROWTH WEIGHTING
   ------------------------------------------------------------
    - Evaluate market contribution to inform growth prioritization
   ============================================================ */

-- market-level demand concentration for growth weighting
WITH market_performance AS (
    SELECT
        market,
        COUNT(DISTINCT country) AS country_count,
        SUM(sales) AS total_sales,
        COUNT(*) AS total_order,
        AVG(sales) AS AOV,
        SUM(sales) / NULLIF(SUM(SUM(sales)) OVER(),0) AS sales_pct
    FROM #stg_sales_analysis
    GROUP BY market
)

SELECT
    market,
    country_count AS country_count,
    FORMAT(total_sales / 1e6, 'N2') AS 'revenue(M)',
    FORMAT(sales_pct, 'P2') AS market_revenue_pct,
    FORMAT(total_order, 'N0') AS order_count,
    FORMAT(AOV, 'N2') AS AOV,
    FORMAT((total_sales / country_count) / 1e6, 'N2') AS 'avg_country_revenue(M)',
    FORMAT(total_order / country_count, 'N0') AS 'country_orders'
FROM market_performance
ORDER BY total_sales DESC;



/* ------------------------------------------------------------
    FINDINGS
   ------------------------------------------------------------
    - Revenue Concentration:
        - APAC, EU, US, and LATAM account for 87% of total revenue.
        - Growth focus outside these markets would have limited impact.
    
    - Coverage-Driven Markets:
        - APAC, EU, and LATAM are structurally broad-based rather than driven by single-country concentration.
        - Country-level prioritization is not required to justify investment in these markets.
    
    - Demand-Dense Market:
        - The US delivers comparable revenue from a single country via high order concentration.
        - US growth depends more on demand intensity than geographic expansion.
    
    - Low-Intensity Markets:
        - Africa and EMEA show broad presence with limited demand.
        - Geographic expansion in these markets is unlikely to yield material growth.
    
    - Low-Contribution Market:
        - Canada contributes minimally to revenue and orders.
        - Canada should not be treated as a growth priority market.
   ------------------------------------------------------------ */



---------------------------------------------------------------
-- MARKET REVENUE CONCENTRATION ORDER
---------------------------------------------------------------

-- market ranking reference table
SELECT
    market,
    ROW_NUMBER() OVER(ORDER BY total_sales DESC) AS rank_order
INTO #market_revenue_order
FROM (
    SELECT
        market,
        SUM(sales) AS total_sales
    FROM #stg_sales_analysis
    GROUP BY market
) AS market_order;



/* ============================================================
    CATEGORY DEMAND MIX & INVESTMENT RELEVANCE
   ------------------------------------------------------------
    - Assess category mix to inform product investment prioritization
   ============================================================ */

-- category revenue mix by market for investment comparison
WITH product_mix AS (
    SELECT
        market,
        category,
        SUM(sales) AS total_sales
    FROM #stg_sales_analysis
    GROUP BY
        market,
        category
)

SELECT
    PM.market,
    PM.category,
    FORMAT(PM.total_sales, 'N0') AS revenue,
    RANK() OVER(PARTITION BY PM.market ORDER BY PM.total_sales DESC) AS rank_in_market,
    FORMAT(
        PM.total_sales/ NULLIF(SUM(PM.total_sales) OVER(PARTITION BY PM.market), 0),'P2'
    ) AS market_category_revenue_pct
FROM product_mix AS PM
JOIN #market_revenue_order AS MRO
    ON PM.market = MRO.market
ORDER BY 
    MRO.rank_order;




/* ------------------------------------------------------------
    FINDINGS
   ------------------------------------------------------------
    - Category Investment Concentration
        - Across most markets, revenue concentrates in the top two categories, with a sharp drop to the third.
        - This rules out equal investment across all categories.

    - Technology as a Structural Growth Driver
        - Technology is the top revenue category across nearly all markets.
        - Technology functions as the primary revenue anchor across nearly all markets.

    - Secondary Categories Require Market-Specific Decisions
        - Furniture and Office Supplies compete closely for second position, with rankings varying by market.
        - Secondary category prioritization should be market-specific, not globally standardized.

    - US as a Category-Balanced Exception
        - The US shows a more evenly distributed category mix.
        - This supports broader category investment in the US compared to other markets.
   ------------------------------------------------------------ */



/* ============================================================
    PRICING & DISCOUNT-DRIVEN DEMAND DYNAMICS
   ------------------------------------------------------------
    - Evaluate the role of discounting in sustaining vs stimulating demand
   ============================================================ */

-- discount intensity buckets to assess demand quality by market
WITH market_sensitivity AS (
    SELECT
        market,
        discount_Level,
        COUNT(market) AS order_count,
        AVG(sales) AS AOV
    FROM (
        SELECT
            market,
            CASE WHEN discount > 0.20 THEN 'Aggressive (>20%)'
                ELSE 'No/Low (0-20%)'
            END AS discount_level,
            sales
        FROM #stg_sales_analysis
    ) AS source_table
    GROUP BY
        market,
        discount_level
)

SELECT
    MS.market,
    MS.discount_level,
    FORMAT(MS.order_count, 'N0') AS order_count,
    FORMAT(
        CAST(MS.order_count AS DECIMAL(18,4)) /
        NULLIF(SUM(MS.order_count) OVER(PARTITION BY MS.market), 0), 'P2'
    ) AS order_pct,
    FORMAT(MS.AOV, 'N0') AS AOV
FROM market_sensitivity AS MS
JOIN #market_revenue_order AS MRO
    ON MS.market = MRO.market
ORDER BY 
    MRO.rank_order,
    CASE
        WHEN MS.discount_level = 'No/Low (0-20%)' THEN 1
        WHEN MS.discount_level = 'Aggressive (>20%)' THEN 2
    END;


/* ------------------------------------------------------------
    FINDINGS
   ------------------------------------------------------------
    - Demand-Led Core Markets (APAC, EU, US, LATAM)
        - Across core markets, 74–86% of orders occur at No/Low discounts (≤20%), 
          indicating that demand largely exists without heavy incentives.
        - Aggressive discounting (>20%) is not required to sustain order volume and generally corresponds to lower order value, 
          signaling demand activation rather than value creation.
        - Aggressive discounting does not materially improve demand quality or scale in core markets.

    - Discount-Activated, Low-Quality Demand (EMEA & Africa)
        - EMEA and Africa show material reliance on aggressive discounts (22–33% of orders).
        - However, demand activated at aggressive discounts delivers substantially lower AOV, indicating price-only, low-quality demand.
        - Broad discounting primarily activates low-value volume rather than sustainable growth.

    - Full-Price-Only Market (Canada)
        - All observed demand in Canada occurs at No/Low discount levels.
        - Discounting does not function as a volume driver in Canada.
   ------------------------------------------------------------ */



/* ============================================================
    FULFILLMENT COST & DEMAND STRUCTURE
   ------------------------------------------------------------
    - Assess the role of shipping cost in shaping demand distribution
   ============================================================ */

-- shipping mode demand and cost distribution by market
WITH shipping_details AS (
    SELECT
        market,
        ship_mode,
        AVG(shipping_cost) AS ship_cost_avg,
        COUNT(*) AS order_count,
        SUM(sales) AS total_sales
    FROM #stg_sales_analysis
    GROUP BY 
        market,
        ship_mode
)

SELECT
    SD.market,
    ship_mode,
    FORMAT(ship_cost_avg, 'N0') AS ship_cost_avg,
    FORMAT(order_count, 'N0') AS shipmode_total_order_count,
    FORMAT(
        CAST(order_count AS FLOAT) / NULLIF(SUM(order_count) OVER(PARTITION BY SD.market), 0),'P2'
    ) AS shipmode_total_orders_pct,
    FORMAT(total_sales, 'N0') AS shipmode_revenue,
    FORMAT(
        total_sales / NULLIF(SUM(total_sales) OVER(PARTITION BY SD.market), 0), 'P2'
    ) AS shipmode_revenue_pct
FROM shipping_details AS SD
JOIN #market_revenue_order AS MRO
    ON SD.market = MRO.market
ORDER BY
    MRO.rank_order,
    CASE 
        WHEN ship_mode = 'Same Day' THEN 1
        WHEN ship_mode = 'First Class' THEN 2
        WHEN ship_mode = 'Second Class' THEN 3
        ELSE 4
    END;



/* ------------------------------------------------------------
    FINDINGS
   ------------------------------------------------------------
    - Limited Demand Sensitivity to Shipping Speed (All Core Markets)
      - Standard Class consistently accounts for 60% of orders across regions, while faster modes remain capped at 5–15% despite higher costs.
      - Revenue contribution closely mirrors order mix, indicating limited premium value from fast shipping.
      - Shipping speed has limited influence on demand or revenue growth in core markets.

    - Fast Shipping Demand Is Structurally Bounded
      - Adoption of Same Day and First Class remains stable across regions, suggesting demand is largely pre-sorted by willingness to pay.
      - Shipping speed tier adoption remains stable across regions, with limited variation by cost.

    - Canada as a Distinct Fulfillment Case
      - Canada deviates from the global pattern, with lower Standard Class reliance and higher revenue concentration in Second Class.
      - Canada is not representative of global fulfillment behavior.
   ------------------------------------------------------------ */



/* ============================================================
    SEGMENT CONTRIBUTION & DEMAND QUALITY PROFILE
   ------------------------------------------------------------
    - Understand segment-level contribution to revenue and demand concentration
    - Evaluate demand quality via reliance on aggressive promotions
    - Assess segment sensitivity to fulfillment cost pressure
   ============================================================ */

---------------------------------------------------------------
-- SEGMENT SALES AT MIN / MAX COMPLETE YEARS
---------------------------------------------------------------

WITH complete_years AS (
    SELECT YEAR(order_date) AS order_year
    FROM #stg_sales_analysis
    GROUP BY YEAR(order_date)
    HAVING COUNT(DISTINCT MONTH(order_date)) = 12
)
, year_range AS (
    SELECT
        (SELECT MIN(order_year) FROM complete_years) AS min_year,
        (SELECT MAX(order_year) FROM complete_years) AS max_year
)

SELECT
    SSA.market,
    SSA.segment,
    SUM(CASE WHEN YR.min_year = YEAR(SSA.order_date) THEN SSA.sales END) AS sales_min_year,
    SUM(CASE WHEN YR.max_year = YEAR(SSA.order_date) THEN SSA.sales END) AS sales_max_year
INTO #segment_min_max_years_sales
FROM #stg_sales_analysis SSA
CROSS JOIN year_range YR
WHERE YEAR(SSA.order_date) = YR.min_year
   OR YEAR(SSA.order_date) = YR.max_year
GROUP BY
    SSA.market,
    SSA.segment;


---------------------------------------------------------------
-- SEGMENT CONTRIBUTION, DEMAND QUALITY & LTD GROWTH PROFILE
---------------------------------------------------------------

WITH segment_performance AS (
    SELECT
        market,
        segment,
        discount_level,
        SUM(sales) / SUM(SUM(sales)) OVER(PARTITION BY market) AS total_sales_pct
    FROM (
        SELECT
            market,
            segment,
            sales,
            CASE WHEN discount > 0.20 THEN 'Aggressive (>20%)'
                ELSE 'No/Low (0-20%)'
            END AS discount_level
        FROM #stg_sales_analysis
    ) AS source_table
    GROUP BY
        market,
        segment,
        discount_level
)
, promo_composition AS (
    SELECT
        market,
        segment,
        SUM(CASE WHEN discount_level = 'Aggressive (>20%)'
                 THEN total_sales_pct ELSE 0 END) AS aggressive_pct,
        SUM(CASE WHEN discount_level = 'No/Low (0-20%)'
                 THEN total_sales_pct ELSE 0 END) AS nolow_pct
    FROM segment_performance
    GROUP BY market, segment
)
, rank_segments AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY market, segment
            ORDER BY
                total_sales_pct DESC,
                CASE WHEN discount_level = 'No/Low (0-20%)' THEN 1
                    ELSE 2
                END
        ) AS rank_number
    FROM segment_performance
)

SELECT  
    RS.market,
    RS.segment,
    RS.discount_level,
    RS.total_sales_pct AS market_segment_revenue_pct,
    -- PC.aggressive_pct / NULLIF(PC.aggressive_pct + PC.nolow_pct, 0) AS promo_ratio_for_validation,
    CASE 
        WHEN PC.aggressive_pct / NULLIF(PC.aggressive_pct + PC.nolow_pct, 0) >= 0.20 
        THEN 'Yes'
        ELSE 'No'
    END AS promo_sensitive,
    (MMS.sales_max_year - MMS.sales_min_year) / NULLIF(MMS.sales_min_year, 0) AS LTD_growth_rate,
    ROW_NUMBER() OVER(PARTITION BY RS.market ORDER BY total_sales_pct) AS market_segment_rank
INTO #segment_classification_metrics
FROM rank_segments RS
JOIN promo_composition PC
    ON RS.market = PC.market
   AND RS.segment = PC.segment
JOIN #market_revenue_order MRO
    ON RS.market = MRO.market
JOIN #segment_min_max_years_sales MMS
    ON RS.market = MMS.market
   AND RS.segment = MMS.segment
WHERE RS.rank_number = 1
ORDER BY
    MRO.rank_order;



---------------------------------------------------------------
-- SEGMENT SURVIVAL & ELIMINATION FLAGS
-- -------------------------------------------------------------
-- Survival Metrics:
-- Revenue size: Primary gate (dominance-based)
-- Promo dependence: Quality discriminator
-- Growth: Health check only (does not affect survival)
---------------------------------------------------------------

WITH revenue_benchmark AS (
    SELECT
        *,
        AVG(LTD_growth_rate) OVER (PARTITION BY market) AS market_avg_growth,
        MAX(CASE WHEN market_segment_rank = 2 THEN market_segment_revenue_pct END) 
            OVER(PARTITION BY market) AS target_benchmark
    FROM #segment_classification_metrics
)
, classifcation_flags AS(
    SELECT
        market,
        segment,
        market_segment_revenue_pct,
        promo_sensitive,
        target_benchmark,
        CASE
            WHEN LTD_growth_rate >= (market_avg_growth) THEN 'Yes'
            ELSE 'No'
        END AS healthy_growth,
        CASE
            WHEN market_segment_revenue_pct >= (target_benchmark + 0.10) THEN 'Yes'
            ELSE 'No'
        END AS top_contributor
    FROM revenue_benchmark
)
SELECT
    CF.market,
    CF.segment,
    FORMAT(CF.market_segment_revenue_pct, 'P2') AS segment_revenue_pct,
    CF.top_contributor,
    CF.promo_sensitive,
    CASE
        WHEN top_contributor = 'No' THEN 'Deprioritize'
        WHEN promo_sensitive = 'Yes' THEN 'Deprioritize'
        ELSE 'Invest'
    END AS segment_classification
FROM classifcation_flags AS CF
JOIN #market_revenue_order AS MRO
    ON CF.market = MRO.market
ORDER BY
    MRO.rank_order,
    CF.segment


/* ------------------------------------------------------------
    FINDINGS
   ------------------------------------------------------------
    - Consumer as the Only Structurally Dominant Segment
      - Consumer contributes 41–53% of revenue across all markets and is the top contributor everywhere.
      - Consumer demand consistently shows low promo sensitivity.
      - No other segment meets relative dominance thresholds in any market.

    - Non-Consumer Segments Do Not Survive Scale or Quality Filters
      - Corporate 24–29% and Home Office 14–18% never achieve sufficient contribution to influence investment logic.
      - Observed growth in these segments does not overcome lack of scale and, in some cases, lower demand quality.
      
    - Segment Structure Is Globally Consistent
      - Segment mix follows the same pattern across all markets: Consumer > Corporate > Home Office
      - Segment composition does not explain differences in market performance or growth.
   ------------------------------------------------------------ */


/* ============================================================
    END OF EXPLORATORY DATA ANALYSIS SCRIPT
   ============================================================ */