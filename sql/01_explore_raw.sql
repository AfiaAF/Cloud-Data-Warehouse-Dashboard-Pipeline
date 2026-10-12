-- 1) Table Creation

CREATE EXTERNAL TABLE aaf_cloud_pipeline_raw_db.raw (
    trdtype STRING,
    usastate STRING,
    depe STRING,
    disagmot STRING,
    mexstate STRING,
    canprov STRING,
    country STRING,
    value BIGINT,
    shipwt BIGINT,
    freight_charges BIGINT,
    df STRING,
    contcode STRING,
    month INT,
    year INT,
    source_file STRING,
    commodity2 STRING
)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','
STORED AS TEXTFILE
LOCATION 's3://aaf-cloud-pipeline-data-bucket/raw/'
TBLPROPERTIES ('skip.header.line.count'='1');


-- 2) Data Completeness & Null Profiling

SELECT 
    COUNT(*) AS total_records,
    -- Null counts for primary identifiers & categories
    COUNT(*) - COUNT(trdtype) AS missing_trdtype,
    COUNT(*) - COUNT(commodity2) AS missing_commodity,
    COUNT(*) - COUNT(source_file) AS missing_source_file,
    -- Null counts for location attributes
    COUNT(*) - COUNT(usastate) AS missing_usastate,
    COUNT(*) - COUNT(mexstate) AS missing_mexstate,
    COUNT(*) - COUNT(canprov) AS missing_canprov,
    -- Null counts for financial/metrics
    COUNT(*) - COUNT(value) AS missing_value,
    COUNT(*) - COUNT(freight_charges) AS missing_freight
FROM aaf_cloud_pipeline_raw_db.raw;


-- 3) Date Check

SELECT 
    MIN("year") AS min_year,
    MAX("year") AS max_year,
    MIN("month") AS min_month,
    MAX("month") AS max_month,
    -- Flag invalid month ranges safely on the quoted column identifier
    SUM(CASE WHEN "month" < 1 OR "month" > 12 OR "month" IS NULL THEN 1 ELSE 0 END) AS invalid_month_count
FROM aaf_cloud_pipeline_raw_db.raw;


-- 4) Row Count & Structure Check
SELECT * 
FROM aaf_cloud_pipeline_raw_db.raw
LIMIT 10;


-- 5) Missing & Empty String Audit
SELECT 
    -- Key Categories
    SUM(CASE WHEN trdtype IS NULL THEN 1 ELSE 0 END) AS null_trdtype,
    SUM(CASE WHEN commodity2 IS NULL OR TRIM(commodity2) = '' THEN 1 ELSE 0 END) AS missing_or_empty_commodity,
    
    -- Geographical Dimensions
    SUM(CASE WHEN usastate IS NULL OR TRIM(usastate) = '' THEN 1 ELSE 0 END) AS missing_usastate,
    SUM(CASE WHEN mexstate IS NULL OR TRIM(mexstate) = '' THEN 1 ELSE 0 END) AS missing_mexstate,
    SUM(CASE WHEN canprov IS NULL OR TRIM(canprov) = '' THEN 1 ELSE 0 END) AS missing_canprov,
    
    -- Numerical Metrics
    SUM(CASE WHEN value IS NULL THEN 1 ELSE 0 END) AS null_value,
    SUM(CASE WHEN freight_charges IS NULL THEN 1 ELSE 0 END) AS null_freight_charges
FROM aaf_cloud_pipeline_raw_db.raw;


--6) Negative & Zero Value Anomaly Audit
SELECT 
    -- Negative Value Checks
    SUM(CASE WHEN value < 0 THEN 1 ELSE 0 END) AS negative_value_count,
    SUM(CASE WHEN freight_charges < 0 THEN 1 ELSE 0 END) AS negative_freight_count,
    SUM(CASE WHEN shipwt < 0 THEN 1 ELSE 0 END) AS negative_shipwt_count,
    
    -- Zero Value Checks
    SUM(CASE WHEN value = 0 THEN 1 ELSE 0 END) AS zero_value_count,
    SUM(CASE WHEN freight_charges = 0 THEN 1 ELSE 0 END) AS zero_freight_count,
    SUM(CASE WHEN shipwt = 0 THEN 1 ELSE 0 END) AS zero_shipwt_count
FROM aaf_cloud_pipeline_raw_db.raw;


-- 7) Metric Range Profiling & Extreme Outlier Detection
SELECT 
    -- Trade Value
    MIN(value) AS min_value,
    MAX(value) AS max_value,
    ROUND(AVG(value), 2) AS avg_value,
    ROUND(STDDEV(value), 2) AS stddev_value,
    
    -- Freight Charges
    MIN(freight_charges) AS min_freight,
    MAX(freight_charges) AS max_freight,
    ROUND(AVG(freight_charges), 2) AS avg_freight,
    
    -- Shipping Weight
    MIN(shipwt) AS min_shipwt,
    MAX(shipwt) AS max_shipwt,
    ROUND(AVG(shipwt), 2) AS avg_shipwt
FROM aaf_cloud_pipeline_raw_db.raw;


-- 8) Source File Line-Count Consistency Check

SELECT 
    source_file,
    COUNT(*) AS total_file_records,
    SUM(CASE WHEN value IS NULL THEN 1 ELSE 0 END) AS null_values_in_file,
    SUM(value) AS total_file_trade_value,
    SUM(freight_charges) AS total_file_freight_charges
FROM aaf_cloud_pipeline_raw_db.raw
GROUP BY source_file
ORDER BY total_file_records DESC;

