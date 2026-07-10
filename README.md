# homelab

Personal GCP lab: **platform** (Terraform + Ansible) and **applications** (data pipelines).

| Layer | Path | Purpose |
|-------|------|---------|
| **Platform** | **`infra/`** | GCP — VPC, VM, BigQuery datasets/tables, IAM |
| **Platform** | **`config/`** | Ansible converge on VMs — **`config/README.md`** |
| **Application** | **`pipelines/`** | Airflow DAGs + SQL — jobs that use BigQuery |
| **Docs** | **`docs/`** | Layout, CI, networking |

**Boundary:** `infra/` = where data lives; `pipelines/` = what you do with it. See **`docs/repo-layout.md`**.

| Doc | Topic |
|-----|-------|
| **`docs/repo-layout.md`** | Platform vs application split |
| **`docs/networking.md`** | Cloud NAT, IAP, SSH |
| **`docs/ci.md`** | GitHub Actions (platform only) |
| **`docs/observability-warehouse.md`** | Future billing/CI metrics in BigQuery |

## Quick start (platform)

```bash
cd infra && cp terraform.tfvars.example terraform.tfvars && terraform init && terraform apply
cd ../config && ansible-playbook site.yml
```

## Quick start (application)

See **`pipelines/README.md`**. No active pipelines — add new DAGs under `pipelines/dags/` when ready.
