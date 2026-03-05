/* ============================================================
   03_staging_layer.sql
   Clean + type-cast the raw data. This is where we:
     - cast strings to real types
     - drop exact duplicate orders
     - default a missing quantity to 1
     - keep only rows that reference valid customers/products
   ============================================================ */

USE DATABASE RETAIL_DB;
USE SCHEMA STG;
USE WAREHOUSE RETAIL_WH;

-- Dimensions are small: full refresh each run is fine.
CREATE OR REPLACE TABLE STG_CUSTOMERS AS
SELECT
    customer_id::NUMBER          AS customer_id,
    INITCAP(TRIM(first_name))    AS first_name,
    INITCAP(TRIM(last_name))     AS last_name,
    LOWER(TRIM(email))           AS email,
    INITCAP(TRIM(city))          AS city,
    INITCAP(TRIM(country))       AS country,
    TRY_TO_DATE(signup_date)     AS signup_date
FROM RAW.RAW_CUSTOMERS
WHERE customer_id IS NOT NULL;

CREATE OR REPLACE TABLE STG_PRODUCTS AS
SELECT
    product_id::NUMBER               AS product_id,
    TRIM(product_name)               AS product_name,
    INITCAP(TRIM(category))          AS category,
    TRY_TO_DECIMAL(unit_price, 10, 2) AS unit_price
FROM RAW.RAW_PRODUCTS
WHERE product_id IS NOT NULL;

-- Orders: this table is fed incrementally by the Task in 04.
-- We create it once with the cleaned shape, seeded from what's in RAW today.
CREATE OR REPLACE TABLE STG_ORDERS (
    order_id     NUMBER,
    customer_id  NUMBER,
    product_id   NUMBER,
    quantity     NUMBER,
    order_ts     TIMESTAMP_NTZ,
    status       VARCHAR,
    _loaded_at   TIMESTAMP_NTZ
);

-- Reusable cleaning logic as a view over RAW, with dedup.
CREATE OR REPLACE VIEW V_CLEAN_ORDERS AS
WITH deduped AS (
    SELECT
        order_id::NUMBER                       AS order_id,
        customer_id::NUMBER                    AS customer_id,
        product_id::NUMBER                     AS product_id,
        COALESCE(TRY_TO_NUMBER(quantity), 1)   AS quantity,
        TRY_TO_TIMESTAMP_NTZ(order_ts)         AS order_ts,
        UPPER(TRIM(status))                    AS status,
        ROW_NUMBER() OVER (
            PARTITION BY order_id
            ORDER BY _loaded_at DESC
        )                                      AS rn
    FROM RAW.RAW_ORDERS
    WHERE order_id IS NOT NULL
)
SELECT order_id, customer_id, product_id, quantity, order_ts, status
FROM deduped
WHERE rn = 1;   -- keep one row per order_id

-- Initial seed load into the staging table.
INSERT INTO STG_ORDERS (order_id, customer_id, product_id, quantity, order_ts, status, _loaded_at)
SELECT c.order_id, c.customer_id, c.product_id, c.quantity, c.order_ts, c.status, CURRENT_TIMESTAMP()
FROM V_CLEAN_ORDERS c
WHERE c.customer_id IN (SELECT customer_id FROM STG_CUSTOMERS)
  AND c.product_id  IN (SELECT product_id  FROM STG_PRODUCTS);

SELECT COUNT(*) AS staged_orders FROM STG_ORDERS;
