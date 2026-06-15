# Repository layout

One repo, two layers. **Platform** provisions GCP; **applications** use it.

```
homelab/
├── infra/       # platform — where data and compute live
├── config/      # platform — VM baseline (Ansible)
├── pipelines/   # application — jobs that load and transform data
└── docs/
```

## Platform (`infra/`, `config/`)

**Owns:** GCP project resources you provision once and share.

| Concern | Location |
|---------|----------|
| VPC, VM, IAP, NAT | `infra/` |
| BigQuery datasets and table shells | `infra/modules/bigquery/` |
| IAM for CI and humans (via Terraform + GitHub vars) | `infra/` |
| VM converge | `config/` |

**Deployed by:** `terraform apply` locally and/or CI on merge to `main` (paths under `infra/**`, `config/**`).

**Rule:** If it’s a GCP resource with a Terraform resource block, it lives in `infra/`.

## Application (`pipelines/`)

**Owns:** Code that runs on a schedule or on demand — extract, load, transform logic — not cloud provisioning.

| Concern | Location |
|---------|----------|
| Airflow DAGs | `pipelines/dags/` |
| Transform SQL | `pipelines/sql/` |
| Python deps for local Airflow | `pipelines/requirements.txt` |
| Local env template | `pipelines/.env.example` |
| Docker runtime | `pipelines/docker-compose.yml` |

**Deployed by:** You, on your Mac (`docker compose up` in `pipelines/`). Nothing in CI deploys `pipelines/` yet.

**Rule:** If it orchestrates or queries data but doesn’t create GCP infrastructure, it lives in `pipelines/`.

## Contract between layers

| Platform (`infra/`) | Application (`pipelines/`) |
|---------------------|----------------------------|
| Creates `homelab` dataset | Assumes dataset exists |
| Creates `raw_*` table schema | Inserts rows into `raw_*` |
| Grants BQ IAM via Terraform | Uses ADC / your user creds |
| — | Creates `stg_*` / `mart_*` via SQL in DAG tasks |

Table names and project ID are configured in the DAG (`GCP_PROJECT_ID`, `BQ_DATASET_ID`) and must match Terraform outputs.

Adding a new pipeline:

1. **Platform PR** — new raw table (and IAM if needed) in `infra/modules/bigquery/`
2. **Application PR** — new folder or DAG under `pipelines/` (can be same PR while learning)

## CI scope

GitHub Actions watches **`infra/**`** and **`config/**`** only. Changes under **`pipelines/`** do not trigger Terraform or Ansible. That’s intentional: platform CI stays separate from app code until you add a pipeline deploy workflow.

## Related

- **`docs/data-pipeline.md`** — film permits walkthrough (first app)
- **`docs/ci.md`** — platform CI variables
- **`pipelines/README.md`** — run the app locally
