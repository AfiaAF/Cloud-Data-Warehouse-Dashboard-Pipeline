-- 1) Curated Data Modelling


CREATE TABLE aaf_cloud_pipeline_raw_db.curated_trade_kpis
WITH (
  format = 'PARQUET',
  parquet_compression = 'SNAPPY',
  external_location = 's3://aaf-cloud-pipeline-data-bucket/curated/'
) AS
SELECT 
  trade_year,
  trade_month,
  trdtype,
  commodity2,
  usastate,
  country,
  COUNT(*) AS total_shipments,
  SUM(trade_value) AS aggregate_trade_value,
  SUM(shipping_weight) AS aggregate_shipping_weight,
  SUM(freight_charges) AS aggregate_freight_charges,
  ROUND(AVG(freight_charges), 2) AS avg_freight_charge
FROM aaf_cloud_pipeline_raw_db.processed_trade_data
GROUP BY 
  trade_year,
  trade_month,
  trdtype,
  commodity2,
  usastate,
  country;


-- 2) Curated Data Population Check

SELECT * 
FROM aaf_cloud_pipeline_raw_db.curated_trade_kpis 
ORDER BY aggregate_trade_value DESC 
LIMIT 10;



-- 3) Grain Uniqueness (Primary Key Check)

SELECT 
    trade_year,
    trade_month,
    trdtype,
    commodity2,
    usastate,
    country,
    COUNT(*) AS duplicate_count
FROM aaf_cloud_pipeline_raw_db.curated_trade_kpis
GROUP BY 
    trade_year,
    trade_month,
    trdtype,
    commodity2,
    usastate,
    country
HAVING COUNT(*) > 1;


-- 4) Reconciliation with Source (Processed vs. Curated)

WITH source_totals AS (
    SELECT 
        COUNT(*) AS total_shipments,
        SUM(trade_value) AS aggregate_trade_value,
        SUM(shipping_weight) AS aggregate_shipping_weight,
        SUM(freight_charges) AS aggregate_freight_charges
    FROM aaf_cloud_pipeline_raw_db.processed_trade_data
),
curated_totals AS (
    SELECT 
        SUM(total_shipments) AS total_shipments,
        SUM(aggregate_trade_value) AS aggregate_trade_value,
        SUM(aggregate_shipping_weight) AS aggregate_shipping_weight,
        SUM(aggregate_freight_charges) AS aggregate_freight_charges
    FROM aaf_cloud_pipeline_raw_db.curated_trade_kpis
)
SELECT 
    s.total_shipments - c.total_shipments AS shipment_count_diff,
    s.aggregate_trade_value - c.aggregate_trade_value AS trade_value_diff,
    s.aggregate_shipping_weight - c.aggregate_shipping_weight AS weight_diff,
    s.aggregate_freight_charges - c.aggregate_freight_charges AS freight_diff
FROM source_totals s
CROSS JOIN curated_totals c;


-- 5) Null & Missing Value Integrity

SELECT 
    COUNT(*) AS total_rows,
    COUNT(CASE WHEN trade_year IS NULL THEN 1 END) AS null_trade_year,
    COUNT(CASE WHEN trade_month IS NULL THEN 1 END) AS null_trade_month,
    COUNT(CASE WHEN trdtype IS NULL THEN 1 END) AS null_trdtype,
    COUNT(CASE WHEN total_shipments IS NULL THEN 1 END) AS null_total_shipments,
    COUNT(CASE WHEN aggregate_trade_value IS NULL THEN 1 END) AS null_trade_value
FROM aaf_cloud_pipeline_raw_db.curated_trade_kpis;


-- 6) Business Logic & Anomaly Boundary Checks

SELECT *
FROM aaf_cloud_pipeline_raw_db.curated_trade_kpis
WHERE total_shipments <= 0
   OR aggregate_trade_value < 0
   OR aggregate_shipping_weight < 0
   OR aggregate_freight_charges < 0
   OR trade_month NOT BETWEEN 1 AND 12
   OR trade_year < 2000 OR trade_year > 2026;

