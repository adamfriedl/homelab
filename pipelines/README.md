# Pipelines — application layer

Jobs that extract, load, and transform data in GCP. Runs in **Docker** on your Mac against resources created by **`infra/`**.

**Platform contract:** **`docs/repo-layout.md`**

No active pipelines right now. The NYC film permits app was removed; the `homelab` BigQuery dataset remains for future work (observability, new pipelines).

## Layout

```
pipelines/
  dags/              # Airflow DAGs (add new pipelines here)
  sql/               # Transform SQL referenced by DAG tasks
  requirements.txt
  Dockerfile
  docker-compose.yml
  .env.example
```

## Prerequisites

Platform must exist first — merge **`infra/`** changes or `terraform apply` locally so the `homelab` dataset exists and your user has BQ IAM (CI handles IAM if **`IAP_SSH_TUNNEL_MEMBER`** is set — **`docs/ci.md`**).

Host:

- Docker Desktop (or compatible Docker engine)
- `gcloud auth application-default login` (ADC mounted into the container)

## Run local Airflow (scaffold)

```bash
gcloud auth application-default login
gcloud config set project gcp-lab-497423

cd pipelines
cp .env.example .env

docker compose up --build
```

Open http://localhost:8080 — the standalone entrypoint prints the admin password in the container logs on first start:

```bash
docker compose logs airflow | grep -i password
```

Stop:

```bash
docker compose down
```

DAG run history persists in the `airflow-meta` volume. Code mounts live from `./dags` and `./sql`.

## Adding a pipeline

1. **Platform PR** — new raw table (and IAM if needed) in `infra/modules/bigquery/`
2. **Application PR** — new DAG + `sql/` under **`pipelines/`**

See **`docs/repo-layout.md`** for the platform vs application split.
