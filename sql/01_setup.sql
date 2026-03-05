/* ============================================================
   01_setup.sql
   Provision the compute + database objects for the pipeline.
   Run as a role with CREATE WAREHOUSE / CREATE DATABASE rights
   (SYSADMIN works on a trial account).
   ============================================================ */

USE ROLE SYSADMIN;

-- Small, cost-friendly warehouse that parks itself after 60s idle.
CREATE WAREHOUSE IF NOT EXISTS RETAIL_WH
    WAREHOUSE_SIZE = 'XSMALL'
    AUTO_SUSPEND   = 60
    AUTO_RESUME    = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'Compute for the retail analytics pipeline';

CREATE DATABASE IF NOT EXISTS RETAIL_DB
    COMMENT = 'Retail sales analytics demo';

USE DATABASE RETAIL_DB;

-- Three layers: landing (RAW), cleaned (STG), serving (MART).
CREATE SCHEMA IF NOT EXISTS RAW   COMMENT = 'Landing zone - source data as-is';
CREATE SCHEMA IF NOT EXISTS STG   COMMENT = 'Cleaned, typed, deduplicated';
CREATE SCHEMA IF NOT EXISTS MART  COMMENT = 'Dimensional model + reporting views';

USE WAREHOUSE RETAIL_WH;
