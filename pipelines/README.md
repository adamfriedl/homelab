# Pipelines — application layer

Jobs that extract, load, and transform data in GCP. Runs on **your Mac** (Airflow) against resources created by **`infra/`**.

**Platform contract:** **`docs/repo-layout.md`**

## This app: NYC film permits

**[Film Permits](https://data.cityofnewyork.us/City-Government/Film-Permits/tg4x-b46p)** (`tg4x-b46p`) → BigQuery `homelab` → Looker Studio.

| Platform (Terraform) | Application (this folder) |
|----------------------|---------------------------|
| `raw_film_permits` table | DAG loads API rows |
| Dataset + IAM | `stg_*` / `mart_*` SQL in DAG tasks |

Full walkthrough: **`docs/data-pipeline.md`**.

## Layout

```
pipelines/
  dags/film_permits_dag.py
  sql/stg_film_permits.sql
  sql/mart_film_permits_daily.sql
  requirements.txt
  .env.example
```

## Prerequisites

Platform must exist first — merge **`infra/`** BigQuery changes or `terraform apply` locally so `homelab.raw_film_permits` exists and your user has BQ IAM (CI handles IAM if **`IAP_SSH_TUNNEL_MEMBER`** is set — **`docs/ci.md`**).

## Run locally

```bash
gcloud auth application-default login
gcloud config set project gcp-lab-497423

cd pipelines
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env   # optional SOCRATA_APP_TOKEN

export AIRFLOW_HOME=~/airflow-homelab
export GCP_PROJECT_ID=gcp-lab-497423
export BQ_DATASET_ID=homelab

airflow db init          # first time only
ln -sf "$(pwd)/dags" "$AIRFLOW_HOME/dags/homelab"
airflow standalone
```

Open http://localhost:8080 → trigger **`nyc_film_permits`**.

## Verify

```sql
SELECT borough, category, SUM(permit_count) AS permits
FROM `gcp-lab-497423.homelab.mart_film_permits_daily`
GROUP BY 1, 2
ORDER BY permits DESC;
```

## Adding another pipeline

Add a new DAG + `sql/` under **`pipelines/`**. If you need a new raw table, add it in **`infra/modules/bigquery/`** first.
