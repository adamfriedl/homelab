CREATE OR REPLACE TABLE `{project_id}.{dataset_id}.mart_film_permits_daily`
PARTITION BY permit_date
AS
SELECT
  DATE(startdatetime) AS permit_date,
  borough,
  category,
  eventtype,
  COUNT(*) AS permit_count,
  COUNTIF(parkingheld IS NOT NULL AND parkingheld != 'None') AS permits_with_parking_hold,
  APPROX_TOP_COUNT(subcategoryname, 1)[OFFSET(0)].value AS top_subcategory
FROM `{project_id}.{dataset_id}.stg_film_permits`
GROUP BY 1, 2, 3, 4;
