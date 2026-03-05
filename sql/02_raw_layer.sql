/* ============================================================
   02_raw_layer.sql
   File format + internal stage + raw landing tables.
   Load the CSVs into the stage BEFORE running the COPY INTO block
   (see README step 3).
   ============================================================ */

USE DATABASE RETAIL_DB;
USE SCHEMA RAW;
USE WAREHOUSE RETAIL_WH;

-- Reusable CSV format: header row, comma-delimited, empty string -> NULL.
CREATE OR REPLACE FILE FORMAT RETAIL_CSV_FMT
    TYPE = 'CSV'
    FIELD_DELIMITER = ','
    SKIP_HEADER = 1
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    NULL_IF = ('', 'NULL')
    EMPTY_FIELD_AS_NULL = TRUE
    TRIM_SPACE = TRUE;

-- Internal stage the CSVs will be uploaded to.
CREATE STAGE IF NOT EXISTS RETAIL_STAGE
    FILE_FORMAT = RETAIL_CSV_FMT
    COMMENT = 'Internal stage for retail source files';

-- Landing tables: everything as VARCHAR so a bad row never breaks the load.
CREATE OR REPLACE TABLE RAW_CUSTOMERS (
    customer_id  VARCHAR,
    first_name   VARCHAR,
    last_name    VARCHAR,
    email        VARCHAR,
    city         VARCHAR,
    country      VARCHAR,
    signup_date  VARCHAR,
    _loaded_at   TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

CREATE OR REPLACE TABLE RAW_PRODUCTS (
    product_id    VARCHAR,
    product_name  VARCHAR,
    category      VARCHAR,
    unit_price    VARCHAR,
    _loaded_at    TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

CREATE OR REPLACE TABLE RAW_ORDERS (
    order_id     VARCHAR,
    customer_id  VARCHAR,
    product_id   VARCHAR,
    quantity     VARCHAR,
    order_ts     VARCHAR,
    status       VARCHAR,
    _loaded_at   TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

/* ---- Upload files to @RETAIL_STAGE, then load ---------------
   SnowSQL:  PUT file://data/*.csv @RETAIL_DB.RAW.RETAIL_STAGE;
   Snowsight: RAW schema -> Stages -> RETAIL_STAGE -> +Files
   ------------------------------------------------------------- */

COPY INTO RAW_CUSTOMERS (customer_id, first_name, last_name, email, city, country, signup_date)
    FROM @RETAIL_STAGE/customers.csv
    FILE_FORMAT = (FORMAT_NAME = RETAIL_CSV_FMT)
    ON_ERROR = 'ABORT_STATEMENT';

COPY INTO RAW_PRODUCTS (product_id, product_name, category, unit_price)
    FROM @RETAIL_STAGE/products.csv
    FILE_FORMAT = (FORMAT_NAME = RETAIL_CSV_FMT)
    ON_ERROR = 'ABORT_STATEMENT';

COPY INTO RAW_ORDERS (order_id, customer_id, product_id, quantity, order_ts, status)
    FROM @RETAIL_STAGE/orders.csv
    FILE_FORMAT = (FORMAT_NAME = RETAIL_CSV_FMT)
    ON_ERROR = 'CONTINUE';   -- tolerate the messy row(s) in the sample file

-- Sanity check.
SELECT 'customers' AS tbl, COUNT(*) AS rows FROM RAW_CUSTOMERS
UNION ALL SELECT 'products', COUNT(*) FROM RAW_PRODUCTS
UNION ALL SELECT 'orders',   COUNT(*) FROM RAW_ORDERS;
