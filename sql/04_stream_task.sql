/* ============================================================
   04_stream_task.sql
   Change Data Capture: a STREAM tracks new rows landing in
   RAW_ORDERS, and a scheduled TASK merges only those new rows
   into STG_ORDERS. This is the incremental heart of the pipeline.
   ============================================================ */

USE DATABASE RETAIL_DB;
USE SCHEMA STG;
USE WAREHOUSE RETAIL_WH;

-- Stream over the raw orders table. It exposes rows inserted
-- since the last time a DML statement consumed the stream.
CREATE OR REPLACE STREAM ORDERS_STREAM
    ON TABLE RAW.RAW_ORDERS
    APPEND_ONLY = TRUE
    COMMENT = 'CDC feed of newly landed raw orders';

-- Task: every 5 minutes, if the stream has data, clean + merge it.
-- MERGE handles both new orders and late-arriving updates to an order.
CREATE OR REPLACE TASK LOAD_ORDERS_TASK
    WAREHOUSE = RETAIL_WH
    SCHEDULE  = '5 MINUTE'
    WHEN SYSTEM$STREAM_HAS_DATA('ORDERS_STREAM')
AS
    MERGE INTO STG_ORDERS AS tgt
    USING (
        SELECT
            order_id::NUMBER                     AS order_id,
            customer_id::NUMBER                  AS customer_id,
            product_id::NUMBER                   AS product_id,
            COALESCE(TRY_TO_NUMBER(quantity), 1) AS quantity,
            TRY_TO_TIMESTAMP_NTZ(order_ts)       AS order_ts,
            UPPER(TRIM(status))                  AS status,
            ROW_NUMBER() OVER (
                PARTITION BY order_id ORDER BY _loaded_at DESC
            )                                    AS rn
        FROM ORDERS_STREAM
        WHERE order_id IS NOT NULL
        QUALIFY rn = 1
    ) AS src
    ON tgt.order_id = src.order_id
    WHEN MATCHED THEN UPDATE SET
        tgt.customer_id = src.customer_id,
        tgt.product_id  = src.product_id,
        tgt.quantity    = src.quantity,
        tgt.order_ts    = src.order_ts,
        tgt.status      = src.status,
        tgt._loaded_at  = CURRENT_TIMESTAMP()
    WHEN NOT MATCHED THEN INSERT
        (order_id, customer_id, product_id, quantity, order_ts, status, _loaded_at)
    VALUES
        (src.order_id, src.customer_id, src.product_id, src.quantity,
         src.order_ts, src.status, CURRENT_TIMESTAMP());

-- Tasks start suspended. Resume to activate the schedule.
ALTER TASK LOAD_ORDERS_TASK RESUME;

/* ---- Try it out -------------------------------------------------
   Insert a new order into RAW, then run the task on demand:

     INSERT INTO RAW.RAW_ORDERS (order_id, customer_id, product_id, quantity, order_ts, status)
     VALUES ('1016', '7', '104', '3', '2024-05-22 12:00:00', 'COMPLETED');

     EXECUTE TASK LOAD_ORDERS_TASK;      -- or wait for the 5-min schedule
     SELECT * FROM STG_ORDERS WHERE order_id = 1016;

   Remember to suspend when finished so it stops burning credits:
     ALTER TASK LOAD_ORDERS_TASK SUSPEND;
   ----------------------------------------------------------------- */
