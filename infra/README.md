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

Use **`terraform.tfvars.example`** as the template (**`terraform.tfvars`** is gitignored).

See repository **`README.md`** for the full homelab layout.
