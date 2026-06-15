CREATE OR REPLACE TABLE `{project_id}.{dataset_id}.stg_film_permits`
PARTITION BY DATE(startdatetime)
AS
SELECT
  eventid,
  eventtype,
  startdatetime,
  enddatetime,
  enteredon,
  eventagency,
  parkingheld,
  borough,
  communityboard_s,
  policeprecinct_s,
  category,
  subcategoryname,
  country,
  zipcode_s,
  loaded_at
FROM `{project_id}.{dataset_id}.raw_film_permits`
WHERE startdatetime >= TIMESTAMP('{start_date}')
  AND startdatetime < TIMESTAMP('{end_date}')
  AND eventid IS NOT NULL
  AND borough IS NOT NULL
  AND category IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY eventid ORDER BY loaded_at DESC) = 1;
