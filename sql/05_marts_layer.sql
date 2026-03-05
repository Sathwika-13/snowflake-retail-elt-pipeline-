/* ============================================================
   05_marts_layer.sql
   Serving layer: a small star schema plus business-friendly
   views that BI tools (Sigma, Tableau, Power BI) can point at.
   ============================================================ */

USE DATABASE RETAIL_DB;
USE SCHEMA MART;
USE WAREHOUSE RETAIL_WH;

-- Dimension: customer
CREATE OR REPLACE TABLE DIM_CUSTOMER AS
SELECT
    customer_id,
    first_name || ' ' || last_name AS full_name,
    email,
    city,
    country,
    signup_date
FROM STG.STG_CUSTOMERS;

-- Dimension: product
CREATE OR REPLACE TABLE DIM_PRODUCT AS
SELECT
    product_id,
    product_name,
    category,
    unit_price
FROM STG.STG_PRODUCTS;

-- Fact: one row per completed order line, with revenue precomputed.
CREATE OR REPLACE TABLE FCT_SALES AS
SELECT
    o.order_id,
    o.customer_id,
    o.product_id,
    o.quantity,
    p.unit_price,
    o.quantity * p.unit_price      AS line_revenue,
    o.order_ts,
    o.order_ts::DATE               AS order_date,
    o.status
FROM STG.STG_ORDERS o
JOIN STG.STG_PRODUCTS p ON o.product_id = p.product_id
WHERE o.status = 'COMPLETED';

-- Convenience view: daily revenue.
CREATE OR REPLACE VIEW V_DAILY_REVENUE AS
SELECT
    order_date,
    COUNT(DISTINCT order_id) AS orders,
    SUM(line_revenue)        AS revenue
FROM FCT_SALES
GROUP BY order_date;

-- Convenience view: revenue by category.
CREATE OR REPLACE VIEW V_CATEGORY_REVENUE AS
SELECT
    p.category,
    SUM(f.line_revenue) AS revenue,
    SUM(f.quantity)     AS units_sold
FROM FCT_SALES f
JOIN DIM_PRODUCT p ON f.product_id = p.product_id
GROUP BY p.category;

SELECT * FROM V_CATEGORY_REVENUE ORDER BY revenue DESC;
