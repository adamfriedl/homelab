# CI (GitHub Actions)

Workflow: **`.github/workflows/plan-and-apply.yml`**. Ansible over IAP via **`.github/actions/ansible-gcp-bootstrap`**.

**Scope:** platform only — **`infra/`** and **`config/`**. **`pipelines/`** is not built or deployed by CI (see **`docs/repo-layout.md`**).

## Jobs

| Job | When | Purpose |
|-----|------|---------|
| **validate** | always | `terraform fmt` / `validate` |
| **plan-or-apply** | always | Terraform plan (PR) or apply (`main`) |
| **ansible** | not on weekly schedule | syntax-check; converge on `main` push |

## Repository secrets / variables

| Name | Kind | Purpose |
|------|------|---------|
| **`GCP_WORKLOAD_IDENTITY_PROVIDER`** | secret | WIF provider |
| **`GCP_SERVICE_ACCOUNT`** | secret | CI service account email |
| **`GCP_PROJECT_ID`** | variable | Project ID (required) |
| **`GCP_REGION`**, **`GCP_ZONE`** | variable | Optional overrides |
| **`IAP_SSH_TUNNEL_MEMBER`** | variable | Optional human principal for Terraform IAM (IAP, OS Login, BigQuery) |

**`terraform-ci@…`** must stay in **`iap_ssh_tunnel_members`**, **`os_login_admin_members`**, **`bigquery_data_editor_members`**, and **`bigquery_job_user_members`**. CI builds all four lists from **`IAP_SSH_TUNNEL_MEMBER`** + **`GCP_SERVICE_ACCOUNT`** — same pattern, no emails in git.

## Local OS Login (one-time)

```bash
gcloud compute os-login ssh-keys add --key-file=~/.ssh/google_compute_engine.pub
gcloud compute os-login describe-profile --format='value(posixAccounts[0].username)'
```

Set **`ansible_user`** in **`config/inventory/group_vars/gcp_lab/ssh_common.yml`**.

WIF pool/provider bindings are one-time bootstrap (owner / gcloud), not managed by CI apply.

## One-time bootstrap: project IAM for CI

`roles/editor` on **`terraform-ci@…`** is not enough for Terraform to add **project-level** IAM bindings (`roles/iap.tunnelResourceAccessor`, `roles/compute.osAdminLogin`, `roles/bigquery.jobUser`, etc.). Dataset-scoped BigQuery IAM works without this; project IAM returns `403 Policy update access denied`.

Run once as a project owner (replace project ID and SA email):

```bash
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member="serviceAccount:terraform-ci@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/resourcemanager.projectIamAdmin"
```

Then re-run the failed **Plan and apply** workflow on `main` (or push any `infra/` change) so Terraform can finish **`google_project_iam_member`** resources.

This binding is bootstrap-only — not managed by Terraform (same pattern as WIF).

## Related

- **`docs/networking.md`** — IAP admin SSH
- **`infra/README.md`** — Terraform workflow
