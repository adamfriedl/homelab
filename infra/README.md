# Terraform (`infra/`)

Run Terraform **from this directory**:

```bash
cd infra
terraform init
terraform plan
```

## Networking defaults

| Variable | Typical value | Meaning |
|----------|---------------|---------|
| **`enable_external_public_ip`** | `false` | VM has private IP only |
| **`enable_cloud_nat`** | `false` (steady state) | No ~$30/mo NAT gateway |

With both false, the VM has **no general internet egress**. Tailscale mesh and IAP admin still work.

**Bootstrap a fresh VM:** set **`enable_cloud_nat = true`**, **`terraform apply`**, run Ansible (**`config/`**), join Tailscale, then set **`enable_cloud_nat = false`** and apply again.

**IAM in `terraform.tfvars`:** include both your user and the CI service account in **`iap_ssh_tunnel_members`** and **`os_login_admin_members`** so Terraform does not remove bindings on apply.

**GitHub Actions WIF:** CI authenticates via Workload Identity Federation. The OIDC token includes the repo name (`owner/name`). If you rename the GitHub repository, run **`terraform apply`** once locally so **`github_wif.tf`** grants **`roles/iam.workloadIdentityUser`** for the new repo (default **`adamfriedl/homelab`**). Until then, CI fails with **`iam.serviceAccounts.getAccessToken` denied**.

Use **`terraform.tfvars.example`** as the template (**`terraform.tfvars`** is gitignored).

See repository **`README.md`** for the full homelab layout.
