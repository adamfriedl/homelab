# CI (GitHub Actions)

Workflow: **`.github/workflows/plan-and-apply.yml`**. Ansible over IAP via **`.github/actions/ansible-gcp-bootstrap`**.

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
| **`IAP_SSH_TUNNEL_MEMBER`** | variable | Optional human principal for Terraform IAM |

**`terraform-ci@…`** must stay in **`iap_ssh_tunnel_members`** and **`os_login_admin_members`**.

## Local OS Login (one-time)

```bash
gcloud compute os-login ssh-keys add --key-file=~/.ssh/google_compute_engine.pub
gcloud compute os-login describe-profile --format='value(posixAccounts[0].username)'
```

Set **`ansible_user`** in **`config/inventory/group_vars/gcp_lab/ssh_common.yml`**.

WIF pool/provider bindings are one-time bootstrap (owner / gcloud), not managed by CI apply.

## Related

- **`docs/networking.md`** — IAP admin SSH
- **`infra/README.md`** — Terraform workflow
