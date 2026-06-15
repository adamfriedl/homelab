"""NYC Open Data film permits pipeline."""

from __future__ import annotations

import os
from datetime import datetime, timezone
from pathlib import Path

import requests
from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.providers.google.cloud.operators.bigquery import BigQueryInsertJobOperator
from google.cloud import bigquery

PROJECT_ID = os.environ.get("GCP_PROJECT_ID", "gcp-lab-497423")
DATASET_ID = os.environ.get("BQ_DATASET_ID", "homelab")
RAW_TABLE = f"{PROJECT_ID}.{DATASET_ID}.raw_film_permits"

SODA_DATASET_ID = "tg4x-b46p"
SODA_BASE_URL = f"https://data.cityofnewyork.us/resource/{SODA_DATASET_ID}.json"

SQL_DIR = Path(__file__).resolve().parents[1] / "sql"

DEFAULT_ARGS = {
    "owner": "homelab",
    "retries": 2,
}


def _soda_headers() -> dict[str, str]:
    token = os.environ.get("SOCRATA_APP_TOKEN")
    if not token:
        return {}
    return {"X-App-Token": token}


def _normalize_row(row: dict, loaded_at: datetime) -> dict:
    """Map SODA JSON to the raw BigQuery table schema."""
    return {
        "eventid": str(row["eventid"]),
        "eventtype": row.get("eventtype"),
        "startdatetime": row.get("startdatetime"),
        "enddatetime": row.get("enddatetime"),
        "enteredon": row.get("enteredon"),
        "eventagency": row.get("eventagency"),
        "parkingheld": row.get("parkingheld"),
        "borough": row.get("borough"),
        "communityboard_s": row.get("communityboard_s"),
        "policeprecinct_s": row.get("policeprecinct_s"),
        "category": row.get("category"),
        "subcategoryname": row.get("subcategoryname"),
        "country": row.get("country"),
        "zipcode_s": row.get("zipcode_s"),
        "loaded_at": loaded_at.isoformat(),
    }


def extract_and_load_raw(**context) -> None:
    """Paginate NYC Open Data and load rows into raw_film_permits."""
    params = context["params"]
    start_date = params["start_date"]
    end_date = params["end_date"]
    page_size = int(params["page_size"])

    where = (
        f"startdatetime >= '{start_date}T00:00:00' "
        f"AND startdatetime < '{end_date}T00:00:00'"
    )

    loaded_at = datetime.now(timezone.utc)
    client = bigquery.Client(project=PROJECT_ID)
    offset = 0
    total = 0

    while True:
        response = requests.get(
            SODA_BASE_URL,
            params={
                "$where": where,
                "$order": "startdatetime ASC",
                "$limit": page_size,
                "$offset": offset,
            },
            headers=_soda_headers(),
            timeout=120,
        )
        response.raise_for_status()
        batch = response.json()
        if not batch:
            break

        rows = [_normalize_row(row, loaded_at) for row in batch]
        errors = client.insert_rows_json(RAW_TABLE, rows)
        if errors:
            raise RuntimeError(f"BigQuery insert errors: {errors[:3]}")

        total += len(rows)
        offset += page_size
        if len(batch) < page_size:
            break

    if total == 0:
        raise ValueError(f"No rows returned for window {start_date} to {end_date}")

    print(f"Loaded {total} rows into {RAW_TABLE}")


def render_sql(filename: str, **context) -> str:
    params = context["params"]
    sql = (SQL_DIR / filename).read_text()
    return sql.format(
        project_id=PROJECT_ID,
        dataset_id=DATASET_ID,
        start_date=params["start_date"],
        end_date=params["end_date"],
    )


with DAG(
    dag_id="nyc_film_permits",
    description="Extract film permits from NYC Open Data into BigQuery",
    default_args=DEFAULT_ARGS,
    schedule=None,
    start_date=datetime(2023, 1, 1),
    catchup=False,
    params={
        "start_date": "2023-01-01",
        "end_date": "2027-01-01",
        "page_size": 10000,
    },
    tags=["nyc-open-data", "film-permits", "homelab"],
) as dag:
    extract_load = PythonOperator(
        task_id="extract_and_load_raw",
        python_callable=extract_and_load_raw,
    )

    render_staging = PythonOperator(
        task_id="render_staging_sql",
        python_callable=render_sql,
        op_kwargs={"filename": "stg_film_permits.sql"},
    )

    transform_staging = BigQueryInsertJobOperator(
        task_id="transform_staging",
        project_id=PROJECT_ID,
        configuration={
            "query": {
                "query": "{{ ti.xcom_pull(task_ids='render_staging_sql') }}",
                "useLegacySql": False,
            }
        },
    )

    render_mart = PythonOperator(
        task_id="render_mart_sql",
        python_callable=render_sql,
        op_kwargs={"filename": "mart_film_permits_daily.sql"},
    )

    transform_mart = BigQueryInsertJobOperator(
        task_id="transform_mart",
        project_id=PROJECT_ID,
        configuration={
            "query": {
                "query": "{{ ti.xcom_pull(task_ids='render_mart_sql') }}",
                "useLegacySql": False,
            }
        },
    )

    extract_load >> render_staging >> transform_staging >> render_mart >> transform_mart
