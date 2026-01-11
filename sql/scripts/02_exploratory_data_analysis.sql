/* ============================================================
    Project: Growth Budget Allocation: $3M Strategy for 2015
    File: 02_exploratory_data_analysis.sql
    Author: Bryan Melvida
   
    Purpose:
    - Apply demand and viability checks for budget allocation
    - Surface candidate signals that could actually move the decision
    - Kill narratives that don’t scale or rely on incentives
    - Produce inputs for synthesis, not conclusions
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
    MARKET DEMAND & BUDGET ABSORPTION GATE
   ------------------------------------------------------------
    - Test whether market scale is sufficient to materially absorb incremental budget

    Narrative under test: 
    - Every active market contributes to growth, so budget should be distributed broadly rather than concentrated in a few
   ============================================================ */


WITH market_performance AS (
    SELECT
        market,
        COUNT(DISTINCT country) AS country_count,
        SUM(sales) AS revenue,
        SUM(sales) / NULLIF(SUM(SUM(sales)) OVER(), 0) AS revenue_pct,
        AVG(sales) AS AOV,
        COUNT(*) AS order_count,
        CAST(COUNT(*) AS FLOAT) / NULLIF(SUM(COUNT(*)) OVER(), 0) AS order_count_pct
    FROM #stg_sales_analysis
    GROUP BY market
)
SELECT
    market,
    country_count,
    FORMAT(revenue / 1e6, 'N2') AS 'revenue (in millions)',
    FORMAT(revenue_pct, 'P2') AS revenue_pct,
    FORMAT(AOV, 'N0') AS AOV,
    FORMAT(order_count, 'N0') AS order_count,
    FORMAT(order_count_pct, 'P2') AS order_count_pct
FROM market_performance
ORDER BY revenue DESC;


/* ------------------------------------------------------------
    FINDINGS
   ------------------------------------------------------------
    - Demand Is Concentrated in Core Markets
        - APAC, EU, US, and LATAM account for 87% of revenue and 80% of orders
        - Markets outside this group lack sufficient scale to materially absorb incremental budget
        - Implication: Growth allocation outside core markets has limited impact

    - Geographic Coverage Without Demand Fails the Absorption Test
        - EMEA and Africa show wide geographic presence but low revenue and order contribution
        - Canada shows neither scale nor demand health (low revenue, low order volume, low AOV)
        - Implication: These markets fail the budget absorption gate and should be deprioritized
   ------------------------------------------------------------ */



/* ============================================================
    CORE MARKET STABILITY CHECK
   ------------------------------------------------------------
    - Test directional stability of revenue and demand trends over time
    - Apply elimination rule: more than one negative YoY year or any consecutive YoY declines fails stability
    - Advance only stable markets to allocation consideration; flag failures for deferral or stress testing

    Narrative under test:
    - Surviving core markets must demonstrate historical stability to remain eligible for incremental growth allocation
   ============================================================ */


WITH market_stability_yoy AS (
    SELECT 
        YEAR(order_date) AS order_year,
        market,
        SUM(sales) AS revenue
    FROM #stg_sales_analysis
    WHERE market IN ('APAC', 'EU', 'US', 'LATAM')
    GROUP BY 
        YEAR(order_date),
        market
)
, yoy_preparation AS (
    SELECT
        *,
        LAG(revenue, 1, 0) OVER(PARTITION BY market ORDER BY order_year) AS lag_revenue
    FROM market_stability_yoy
)

SELECT 
    order_year,
    market,
    FORMAT((revenue - lag_revenue) / NULLIF(lag_revenue, 0), 'P2') AS revenue_growth_yoy
FROM yoy_preparation


/* ------------------------------------------------------------
    FINDINGS
   ------------------------------------------------------------
    - Core markets show resilient growth and stable trends over time
        - APAC, EU, and LATAM exhibit sustained positive YoY growth, generally ranging from mid teens to high 30s
        - The US shows a single contraction in 2012 (-2.8%) followed by a strong rebound in 2013 (+29%) and continued growth in 2014 (+21%)
        - No market exhibits multi year decline or repeated YoY contraction
        - Growth persists across consecutive years, supporting budget absorption capacity
        - Implication: Core markets can absorb incremental growth budget and remain eligible allocation candidates
   ------------------------------------------------------------ */



---------------------------------------------------------------
-- REFERENCE TABLES
---------------------------------------------------------------

SELECT core_markets
INTO #core_markets
FROM (VALUES ('APAC'), ('EU'), ('US'), ('LATAM')) list_into(core_markets)

-- core markets total revenue and order count
SELECT 
    SUM(sales) AS total_revenue,
    COUNT(*) AS total_order_count
INTO #total_core_markets
FROM #stg_sales_analysis
WHERE market IN (SELECT * FROM #core_markets)



/* ============================================================
    PRODUCT DEMAND & CAPITAL ABSORPTION GATE
   ------------------------------------------------------------
    - Test whether product level revenue or demand concentration can safely guide incremental allocation

    Narrative under test: 
    - Concentrating incremental investment in top revenue or demand categories is a safe path to scalable growth
   ============================================================ */


WITH product_category_performance AS (
    SELECT
        SSA.category,
        SUM(SSA.sales) AS revenue,
        SUM(SSA.sales) / MAX(TCM.total_revenue) AS revenue_pct,
        COUNT(*) AS order_count,
        CAST(COUNT(*) AS FLOAT) / MAX(TCM.total_order_count) AS order_count_pct
    FROM #stg_sales_analysis AS SSA
    CROSS JOIN #total_core_markets AS TCM
    WHERE SSA.market IN (SELECT * FROM #core_markets)
    GROUP BY
        SSA.category
)

SELECT
    category,
    FORMAT(revenue / 1e6, 'N2') AS 'revenue (in millions)',
    FORMAT(revenue_pct, 'P2') AS revenue_pct,
    FORMAT(order_count, 'N0') AS order_count,
    FORMAT(order_count_pct, 'P2') AS order_count_pct
FROM product_category_performance
ORDER BY 
    revenue DESC;



/* ------------------------------------------------------------
    FINDINGS
   ------------------------------------------------------------
    - Category Revenue and Demand Fail as Allocation Signals
        - Revenue contribution is broadly distributed across categories, with no category clearly dominating total revenue
        - Technology and Furniture generate comparable revenue to Office Supplies with significantly fewer orders
        - Office Supplies accounts for the majority of order volume but contributes the smallest share of revenue
        - Implication: Revenue and demand provide conflicting and non-dominant signals and should not be used to guide budget allocation
   ------------------------------------------------------------ */



/* ============================================================
    INCENTIVE ILLUSION CHECK: PRICING CONTEXT
   ------------------------------------------------------------
    - Test whether discounting explains market scale and can reliably guide allocation decisions

    Narrative under test: 
    - Discounting is a reliable growth lever that explains market scale and should guide where incremental budget is allocated
   ============================================================ */


WITH promo_sensitivity AS (
    SELECT
        ST.market,
        ST.discount_applied,
        SUM(ST.sales) / MAX(TCM.total_revenue) AS market_revenue_pct,
        SUM(sales) AS revenue
    FROM (
        SELECT 
            market,
            CASE WHEN discount > 0 THEN 'Yes'
                ELSE 'No'
            END AS discount_applied,
            sales
        FROM #stg_sales_analysis
        WHERE market IN (SELECT * FROM #core_markets)
    ) AS ST
    CROSS JOIN #total_core_markets AS TCM
    GROUP BY
        ST.market,
        ST.discount_applied
)
, global_totals_pct AS (
    SELECT
        SUM(CASE WHEN PS.discount_applied = 'Yes' 
                THEN PS.market_revenue_pct ELSE 0 END) AS discounted_total_revenue_pct,
        SUM(revenue) / MAX(TCM.total_revenue) AS total_revenue_pct
    FROM promo_sensitivity AS PS
    CROSS JOIN #total_core_markets AS TCM
)

-- Each market's share of global discounted revenue, compared to its share of total revenue
, market_discount_scale_comparison AS (
    SELECT
        PS.market,
        SUM(PS.market_revenue_pct) AS market_revenue_pct,
        SUM(CASE WHEN PS.discount_applied = 'Yes' 
                THEN PS.market_revenue_pct/ GTP.discounted_total_revenue_pct
                ELSE 0 
            END) AS yes_discount_revenue_pct
    FROM promo_sensitivity AS PS
    CROSS JOIN global_totals_pct AS GTP
    GROUP BY market
)    

SELECT
    market,
    FORMAT(market_revenue_pct, 'P2') AS market_revenue_pct,
    FORMAT(yes_discount_revenue_pct, 'P2') AS discounted_revenue_pct,
    CASE WHEN yes_discount_revenue_pct > market_revenue_pct 
        THEN 'Yes'
        ELSE 'No'
    END AS discount_over_indexes_scale
FROM market_discount_scale_comparison
ORDER BY market_revenue_pct DESC;


/* ------------------------------------------------------------
    FINDINGS
   ------------------------------------------------------------
    - Discounting Does Not Reliably Explain Market Scale
        - Discounted revenue over indexes in some large markets and under indexes in others.
        - Over index effects are small and inconsistent across markets.
        - Implication: Discounting fails the consistency gate and should not be used to guide budget allocation
   ------------------------------------------------------------ */



/* ============================================================
    FULFILLMENT BEHAVIOR BOUNDARY: COST CONTEXT
   ------------------------------------------------------------
    - Test whether willingness to pay increases justify premium fulfillment as a scalable growth lever.
    
    Narrative under test: 
    - Faster delivery increases willingness to pay, so investment in premium fulfillment should be a primary growth lever
   ============================================================ */


WITH shipping_mode_performance AS (
    SELECT
        SSA.ship_mode,
        AVG(DATEDIFF(DAY, SSA.order_date, SSA.ship_date)) AS avg_ship_day,
        AVG(SSA.shipping_cost) AS avg_shipping_cost,
        SUM(SSA.sales) / MAX(TCM.total_revenue) AS revenue_pct,
        CAST(COUNT(*) AS FLOAT) / MAX(TCM.total_order_count) AS order_count_pct
    FROM #stg_sales_analysis AS SSA
    CROSS JOIN #total_core_markets AS TCM
    WHERE SSA.market IN (SELECT * FROM #core_markets)
    GROUP BY SSA.ship_mode
)

SELECT
    ship_mode,
    avg_ship_day,
    FORMAT(avg_shipping_cost, 'N0') AS avg_shipping_cost,
    FORMAT(revenue_pct, 'P2') AS revenue_pct,
    FORMAT(order_count_pct, 'P2') AS order_count_pct
FROM shipping_mode_performance
ORDER BY avg_ship_day;


/* ------------------------------------------------------------
    FINDINGS
   ------------------------------------------------------------
    - Faster Delivery Fails to Drive Willingness to Pay
        - Revenue and demand concentrated in Standard Class accounting for 60.4% and 60.2% respectively
        - Higher shipping speed does not correspond to higher revenue or order concentration
        - Demand and revenue scale persist in lower cost, slower fulfillment tiers
        - Implication: Premium shipping modes fail as a scalable growth lever and should not guide allocation decisions
   ------------------------------------------------------------ */



/* ============================================================
    CUSTOMER SEGMENT ALLOCATION SAFETY CHECK
   ------------------------------------------------------------
    - Test whether segment-level investment can be justified beyond market-level allocation

    Narrative under test:
    - High-value customer segments justify dedicated investment even if they represent a small share of total demand
   ============================================================ */


---------------------------------------------------------------
-- Contribution size test (whether a segment matters)
---------------------------------------------------------------
-- Rule: Prioritizes risk management over coverage. Volatility disqualifies segments faster than size qualifies them.


WITH segment_monthly_revenue AS (
    SELECT
        YEAR(order_date) AS order_year,
        MONTH(order_date) AS order_month,
        segment,
        SUM(sales) AS monthly_revenue
    FROM #stg_sales_analysis
    WHERE market in (SELECT * FROM #core_markets) 
        AND YEAR(order_date) IN (2013,2014)
    GROUP BY
        YEAR(order_date),
        MONTH(order_date),
        segment
)
, monthly_total_revenue AS(
    SELECT
        order_year,
        order_month,
        SUM(monthly_revenue) AS total_revenue
    FROM segment_monthly_revenue
    GROUP BY
        order_year,
        order_month
)
, segment_contribution AS (
    SELECT
        segment,
        AVG(contribution_pct) AS mean_pct,
        STDEV(contribution_pct) AS std_dev,
        STDEV(contribution_pct) / AVG(contribution_pct) As CV_pct
    FROM (
        SELECT
            SMR.order_year,
            SMR.order_month,
            SMR.segment,
            CAST(SMR.monthly_revenue AS FLOAT) / MTR.total_revenue AS contribution_pct
        FROM segment_monthly_revenue AS SMR
        JOIN monthly_total_revenue AS MTR
            ON SMR.order_year = MTR.order_year
            AND SMR.order_month = MTR.order_month
    ) AS source_table
    GROUP BY segment
)

SELECT
    segment,
    FORMAT(mean_pct, 'P2') AS avg_contribution_pct,
    FORMAT(std_dev, 'P2') AS contribution_std_dev,
    FORMAT(CV_pct, 'P2') AS contribution_cv_pct
FROM segment_contribution;


/* ------------------------------------------------------------
    TEST RESULT (Fail: Home Office)
   ------------------------------------------------------------
    - Consumer contributes about 50% of total revenue on average and shows the most consistent contribution relative to its size
    - Corporate is the second largest contributor, accounting for 31%, and exhibits some variation but remains reasonably consistent given its size
    - Home Office is excluded, it contributes the least on average and shows the most fluctuation relative to its size
    - While absolute variation is similar across segments, only Consumer and Corporate remain stable once adjusted for size
   ------------------------------------------------------------ */



---------------------------------------------------------------
-- Organic demand test (whether dependency is real or artificial)
---------------------------------------------------------------
-- Rule: Treat demand as artificial unless it persists without incentives or external pressure


WITH promo_sensitivity AS (
    SELECT
        segment,
        discount_applied,
        COUNT(*) AS order_count
    FROM (
        SELECT
            segment,
            sales,
            CASE WHEN discount > 0 THEN 'Yes'
                ELSE 'No'
            END AS discount_applied
        FROM #stg_sales_analysis
        WHERE market IN (SELECT * FROM #core_markets)
            AND segment != 'Home Office'
    ) AS source_table
    GROUP BY 
        segment,
        discount_applied
)
, demand_comparison AS (
    SELECT
        segment,
        SUM(CASE WHEN discount_applied = 'Yes' THEN order_count ELSE 0 END) 
            / CAST(SUM(order_count) AS FLOAT) AS discounted_order_pct
    FROM promo_sensitivity
    GROUP BY segment
)

SELECT
    segment,
    FORMAT(discounted_order_pct, 'P2') AS discounted_order_count_pct
FROM demand_comparison

/* ------------------------------------------------------------
    TEST RESULT (Fail: All Segments)
   ------------------------------------------------------------
    - Discounted orders account for about 47% of volume across all segments
    - Incentive dependence is uniform, with no segment exhibiting organic demand
    - All segments fail the organic demand gate and are ineligible for persistence testing
   ------------------------------------------------------------ */



---------------------------------------------------------------
-- Persistence test (how risky that dependency is)
---------------------------------------------------------------
-- Assesses risk only for segments that already matter and are organic




/* ------------------------------------------------------------
    FINDINGS
   ------------------------------------------------------------
    - Customer Segments Fail as Safe Allocation Targets
        - Home Office fails the contribution size gate due to low and volatile revenue contribution and is excluded
        - Consumer and Corporate contribute the majority of revenue but do not demonstrate organic demand
        - Nearly half of all orders across remaining segments are discount-driven, indicating systemic incentive dependence
        - No segment qualifies for persistence testing
        - Implication: Segment level investment introduces incentive and volatility risk and should be ruled out under a risk-managed growth mandate
   ------------------------------------------------------------ */


/* ============================================================
    END OF EXPLORATORY DATA ANALYSIS SCRIPT
   ============================================================ */