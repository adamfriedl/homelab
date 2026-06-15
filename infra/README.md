# Terraform (`infra/`) — platform

Provisions GCP **resources**: network, VM, BigQuery datasets and raw tables, IAM.

Does **not** contain Airflow DAGs or pipeline SQL — those live in **`pipelines/`** (see **`docs/repo-layout.md`**).

```bash
cd infra
terraform init
terraform plan
```

**Networking:** **`docs/networking.md`**. **CI variables and one-time SA bootstrap:** **`docs/ci.md`** (includes **`projectIamAdmin`** for **`terraform-ci@…`** so CI can apply project IAM).

After apply, note BigQuery outputs:

```bash
terraform output bigquery_dataset_id
terraform output bigquery_raw_film_permits_table
```
