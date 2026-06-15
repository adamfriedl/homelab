# Pipelines — application layer

Jobs that extract, load, and transform data in GCP. Runs in **Docker** on your Mac against resources created by **`infra/`**.

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
  Dockerfile
  docker-compose.yml
  .env.example
```

## Prerequisites

Platform must exist first — merge **`infra/`** BigQuery changes or `terraform apply` locally so `homelab.raw_film_permits` exists and your user has BQ IAM (CI handles IAM if **`IAP_SSH_TUNNEL_MEMBER`** is set — **`docs/ci.md`**).

Host:

- Docker Desktop (or compatible Docker engine)
- `gcloud auth application-default login` (ADC mounted into the container)

## Run locally (Docker)

```bash
gcloud auth application-default login
gcloud config set project gcp-lab-497423

cd pipelines
cp .env.example .env   # optional SOCRATA_APP_TOKEN

docker compose up --build
```

Open http://localhost:8080 — the standalone entrypoint prints the admin password in the container logs on first start:

```bash
docker compose logs airflow | grep -i password
```

Trigger DAG **`nyc_film_permits`** in the UI.

Stop:

```bash
docker compose down
```

DAG run history persists in the `airflow-meta` volume. Code mounts live from `./dags` and `./sql`.

## Verify

```sql
SELECT borough, category, SUM(permit_count) AS permits
FROM `gcp-lab-497423.homelab.mart_film_permits_daily`
GROUP BY 1, 2
ORDER BY permits DESC;
```

## Alternative: venv + `airflow standalone`

See **`docs/data-pipeline.md`** Phase 3 if you prefer a native Python venv without Docker.

## Adding another pipeline

Add a new DAG + `sql/` under **`pipelines/`**. If you need a new raw table, add it in **`infra/modules/bigquery/`** first.
