# Retail Sales Analytics Pipeline — Snowflake

A small, end-to-end data engineering project on **Snowflake** that ingests raw
retail order data, cleans and models it through a layered architecture, and
serves analytics-ready marts. It demonstrates the core building blocks you'd use
on a real warehouse: staging, `COPY INTO`, incremental loading with **Streams +
Tasks**, and dimensional modeling.

## Architecture

```
  CSV files                RAW                 STAGING (ODS)            MARTS
 ┌─────────┐   COPY INTO  ┌─────────┐  Stream  ┌─────────────┐  View  ┌──────────────┐
 │ orders  │ ───────────► │ RAW.*   │ ───────► │ STG.* (typed│ ─────► │ MART.*       │
 │ custs   │   (stage)    │ (VARCHAR│  + Task  │  deduped,   │        │ (facts, dims,│
 │ prods   │              │  landing│          │  validated) │        │  aggregates) │
 └─────────┘              └─────────┘          └─────────────┘        └──────────────┘
```

- **RAW** — landing zone, everything as strings, 1:1 with source files.
- **STG** — cleaned, typed, deduplicated. Incrementally refreshed by a Stream + Task.
- **MART** — star-schema-style dims/facts and business-friendly views for BI tools.

## What it shows

- Warehouse / database / schema provisioning
- Named file format + internal stage + `COPY INTO`
- Type casting, null handling, and dedup logic
- **Change Data Capture** using a `STREAM`
- Automated incremental transforms using a scheduled `TASK`
- SCD-friendly dimensional model
- A dozen analytical queries (revenue trends, RFM, cohort-style repeat rate)

## Repo layout

```
snowflake-retail-pipeline/
├── README.md
├── data/                     # tiny sample CSVs to load
│   ├── customers.csv
│   ├── products.csv
│   └── orders.csv
└── sql/
    ├── 01_setup.sql          # warehouse, db, schemas, roles
    ├── 02_raw_layer.sql      # file format, stage, raw tables, COPY INTO
    ├── 03_staging_layer.sql  # typed/cleaned tables + views
    ├── 04_stream_task.sql    # CDC stream + scheduled incremental task
    ├── 05_marts_layer.sql    # dims, facts, and reporting views
    └── 06_analytics_queries.sql  # business questions answered in SQL
```

## How to run

1. Log into Snowsight (a free trial account works fine).
2. Run the scripts in `sql/` in order, `01` → `06`.
3. In step `02`, upload the CSVs from `data/` to the internal stage:
   - Snowsight: **Data → Databases → RETAIL_DB → RAW → Stages → RETAIL_STAGE → +Files**
   - or SnowSQL: `PUT file://data/*.csv @RETAIL_DB.RAW.RETAIL_STAGE;`
4. Run the `COPY INTO` statements, then continue with `03`–`06`.

## Notes

- Everything uses an `XSMALL` warehouse and auto-suspends after 60s to stay
  within trial credits.
- The Task runs on a 5-minute schedule; suspend it when you're done:
  `ALTER TASK STG.LOAD_ORDERS_TASK SUSPEND;`

## License

MIT
