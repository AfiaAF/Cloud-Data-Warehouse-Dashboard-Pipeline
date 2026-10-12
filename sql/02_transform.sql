-- 1) Processed Data Transformation
CREATE TABLE aaf_cloud_pipeline_raw_db.processed_trade_data
WITH (
  format = 'PARQUET',
  parquet_compression = 'SNAPPY',
  external_location = 's3://aaf-cloud-pipeline-data-bucket/processed/'
) AS
SELECT 
  -- Text Identifiers & Metadata
  CAST(trdtype AS VARCHAR) AS trdtype,
  COALESCE(NULLIF(TRIM(CAST(commodity2 AS VARCHAR)), ''), 'UNKNOWN') AS commodity2,
  CAST(source_file AS VARCHAR) AS source_file,
  
  -- Location Dimensions
  COALESCE(NULLIF(TRIM(CAST(usastate AS VARCHAR)), ''), 'N/A') AS usastate,
  COALESCE(NULLIF(TRIM(CAST(mexstate AS VARCHAR)), ''), 'N/A') AS mexstate,
  COALESCE(NULLIF(TRIM(CAST(canprov AS VARCHAR)), ''), 'N/A') AS canprov,
  CAST(country AS VARCHAR) AS country,
  CAST(depe AS VARCHAR) AS depe,
  CAST(disagmot AS VARCHAR) AS disagmot,
  CAST(contcode AS VARCHAR) AS contcode,

  -- Temporal Integers
  CAST("year" AS INT) AS trade_year,
  CAST("month" AS INT) AS trade_month,
  
  -- Numerical Metrics (Safely cast before COALESCE to guarantee matching types)
  COALESCE(TRY_CAST(value AS BIGINT), 0) AS trade_value,
  COALESCE(TRY_CAST(shipwt AS BIGINT), 0) AS shipping_weight,
  COALESCE(TRY_CAST(freight_charges AS BIGINT), 0) AS freight_charges,
  COALESCE(TRY_CAST(df AS DOUBLE), 0.0) AS df
FROM aaf_cloud_pipeline_raw_db.raw
WHERE 
  (TRY_CAST(value AS BIGINT) >= 0 OR value IS NULL)
  AND (TRY_CAST(freight_charges AS BIGINT) >= 0 OR freight_charges IS NULL)
  AND (CAST("month" AS INT) BETWEEN 1 AND 12 OR "month" IS NULL);


-- 2) Data Hygiene & Null Audit

SELECT 
    COUNT(*) AS total_processed_records,
    
    -- Verify Null Handling
    SUM(CASE WHEN commodity2 = 'UNKNOWN' THEN 1 ELSE 0 END) AS unmapped_commodity_count,
    SUM(CASE WHEN usastate = 'N/A' THEN 1 ELSE 0 END) AS unmapped_state_count,
    
    -- Financial Data Sanity Checks
    SUM(CASE WHEN trade_value < 0 THEN 1 ELSE 0 END) AS negative_value_count,
    SUM(CASE WHEN freight_charges < 0 THEN 1 ELSE 0 END) AS negative_freight_count,
    
    -- Temporal Boundary Audits
    MIN(trade_year) AS min_year,
    MAX(trade_year) AS max_year,
    SUM(CASE WHEN trade_month < 1 OR trade_month > 12 OR trade_month IS NULL THEN 1 ELSE 0 END) AS invalid_month_count,
    
    -- Statistical Aggregates
    ROUND(SUM(trade_value), 2) AS total_trade_value,
    ROUND(AVG(freight_charges), 2) AS avg_freight_charge
FROM aaf_cloud_pipeline_raw_db.processed_trade_data;



-- 3) Reconciliation Check (Raw vs. Silver/Processed Record Count)

SELECT 
    raw_table.raw_count,
    silver_table.silver_count,
    (raw_table.raw_count - silver_table.silver_count) AS dropped_records_count
FROM (
    SELECT COUNT(*) AS raw_count FROM aaf_cloud_pipeline_raw_db.raw
) raw_table
CROSS JOIN (
    SELECT COUNT(*) AS silver_count FROM aaf_cloud_pipeline_raw_db.processed_trade_data
) silver_table;
