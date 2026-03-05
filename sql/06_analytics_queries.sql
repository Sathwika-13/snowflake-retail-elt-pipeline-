/* ============================================================
   06_analytics_queries.sql
   Business questions answered against the MART layer.
   Each block is standalone - run whichever you want.
   ============================================================ */

USE DATABASE RETAIL_DB;
USE SCHEMA MART;
USE WAREHOUSE RETAIL_WH;

-- 1. Total revenue and order count (headline KPIs)
SELECT
    COUNT(DISTINCT order_id) AS total_orders,
    SUM(line_revenue)        AS total_revenue,
    ROUND(AVG(line_revenue), 2) AS avg_line_value
FROM FCT_SALES;

-- 2. Top 5 products by revenue
SELECT
    p.product_name,
    p.category,
    SUM(f.quantity)     AS units_sold,
    SUM(f.line_revenue) AS revenue
FROM FCT_SALES f
JOIN DIM_PRODUCT p ON f.product_id = p.product_id
GROUP BY p.product_name, p.category
ORDER BY revenue DESC
LIMIT 5;

-- 3. Revenue by city (where are our best markets?)
SELECT
    c.city,
    COUNT(DISTINCT f.order_id) AS orders,
    SUM(f.line_revenue)        AS revenue
FROM FCT_SALES f
JOIN DIM_CUSTOMER c ON f.customer_id = c.customer_id
GROUP BY c.city
ORDER BY revenue DESC;

-- 4. Daily revenue with a 3-day moving average (trend smoothing)
SELECT
    order_date,
    revenue,
    ROUND(
        AVG(revenue) OVER (
            ORDER BY order_date
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ), 2
    ) AS revenue_3d_avg
FROM V_DAILY_REVENUE
ORDER BY order_date;

-- 5. Customer lifetime value ranked (top spenders)
SELECT
    c.full_name,
    c.city,
    COUNT(DISTINCT f.order_id) AS orders,
    SUM(f.line_revenue)        AS lifetime_value,
    RANK() OVER (ORDER BY SUM(f.line_revenue) DESC) AS spend_rank
FROM FCT_SALES f
JOIN DIM_CUSTOMER c ON f.customer_id = c.customer_id
GROUP BY c.full_name, c.city
ORDER BY lifetime_value DESC;

-- 6. Repeat vs one-time customers (simple retention signal)
WITH per_customer AS (
    SELECT customer_id, COUNT(DISTINCT order_id) AS order_count
    FROM FCT_SALES
    GROUP BY customer_id
)
SELECT
    CASE WHEN order_count > 1 THEN 'Repeat' ELSE 'One-time' END AS customer_type,
    COUNT(*) AS customers
FROM per_customer
GROUP BY 1;

-- 7. Category share of total revenue (%)
SELECT
    category,
    revenue,
    ROUND(100 * revenue / SUM(revenue) OVER (), 1) AS pct_of_total
FROM V_CATEGORY_REVENUE
ORDER BY revenue DESC;

-- 8. Simple RFM-style scoring (Recency, Frequency, Monetary)
WITH rfm AS (
    SELECT
        c.customer_id,
        c.full_name,
        DATEDIFF('day', MAX(f.order_date), CURRENT_DATE()) AS recency_days,
        COUNT(DISTINCT f.order_id)                         AS frequency,
        SUM(f.line_revenue)                                AS monetary
    FROM FCT_SALES f
    JOIN DIM_CUSTOMER c ON f.customer_id = c.customer_id
    GROUP BY c.customer_id, c.full_name
)
SELECT
    full_name,
    recency_days,
    frequency,
    monetary,
    NTILE(3) OVER (ORDER BY recency_days ASC)  AS r_score,  -- lower recency = better
    NTILE(3) OVER (ORDER BY frequency DESC)    AS f_score,
    NTILE(3) OVER (ORDER BY monetary  DESC)    AS m_score
FROM rfm
ORDER BY monetary DESC;
