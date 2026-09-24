-- Original table Structure Check
SELECT * 
FROM "aaf_cloud_pipeline_data_bucket" 
LIMIT 10;


-- Drop Original Table
DROP TABLE IF EXISTS aaf_cloud_pipeline_raw_db.aaf_cloud_pipeline_data_bucket;


-- Recreating table
CREATE EXTERNAL TABLE aaf_cloud_pipeline_raw_db.raw_table (
  trdtype string,
  usastate string,
  depe string,
  disagmot string,
  mexstate string,
  canprov string,
  country string,
  value bigint,
  shipwt bigint,
  freight_charges bigint,
  df string,
  contcode string,
  month date,
  year date,
  source_file string, 
  commodity2 string

)

ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.lazy.LazySimpleSerDe'
WITH SERDEPROPERTIES (
  'serialization.format' = ',',
  'field.delim' = ','
)
LOCATION 's3://aaf-cloud-pipeline-data-bucket/raw/'
TBLPROPERTIES ('skip.header.line.count'='1');


-- New Table Structure Check
SELECT * 
FROM "raw_table" 
LIMIT 10;

-- Total Rows
SELECT COUNT(*) AS total_rows 
FROM "raw_table";

-- Missing Value Check (using trdtype column)
SELECT 
    COUNT(*) AS total_rows,
    COUNT(trdtype) AS non_null_count,
    COUNT(*) - COUNT(trdtype) AS missing_values
FROM "raw_table";

