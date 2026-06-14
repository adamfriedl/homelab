# CI (GitHub Actions)

Terraform and Ansible run in **`.github/workflows/plan-and-apply.yml`** on **`ubuntu-latest`** with Workload Identity Federation. Ansible reaches **`gcp_lab`** over **IAP SSH** — no home-lab runner.

## Jobs

| Job | Runner | Purpose |
|-----|--------|---------|
| **validate** | `ubuntu-latest` | `terraform fmt` / `validate` |
| **plan-or-apply** | `ubuntu-latest` + WIF | Terraform plan (PR) or apply (`main`) |
| **ansible** | `ubuntu-latest` + WIF | Inventory check, ping, `site.yml --limit gcp_lab` on merge |

## Ansible over IAP

- SSH config: **`config/inventory/group_vars/gcp_lab/iap_ssh.yml`**
- Bootstrap action: **`.github/actions/ansible-gcp-bootstrap`** (WIF, terraform init, ephemeral OS Login key)

**`terraform-ci@…`** must stay in **`iap_ssh_tunnel_members`** and **`os_login_admin_members`** (Terraform grants both).

## Repository secrets / variables

| Name | Kind | Purpose |
|------|------|---------|
| **`GCP_WORKLOAD_IDENTITY_PROVIDER`** | secret | WIF provider |
| **`GCP_SERVICE_ACCOUNT`** | secret | CI service account email |
| **`GCP_PROJECT_ID`** | variable | Project ID |
| **`GCP_REGION`**, **`GCP_ZONE`** | variable | Optional overrides |
| **`IAP_SSH_TUNNEL_MEMBER`** | variable | Optional human principal for Terraform IAM |

## Related

- **`docs/networking.md`** — Cloud NAT, IAP admin SSH
- **`infra/README.md`** — Terraform workflow, WIF bootstrap
