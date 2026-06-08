# Terraform (`infra/`)

Run Terraform **from this directory**:

```bash
cd infra
terraform init
terraform plan
```

**Networking (Tailscale, NAT, bootstrap, SSH):** **`docs/networking.md`**

Steady-state variables (`enable_external_public_ip`, `enable_cloud_nat`): **`docs/networking.md#terraform-knobs`**. Template: **`terraform.tfvars.example`**.

**IAM in `terraform.tfvars`:** include both your user and the CI service account in **`iap_ssh_tunnel_members`** and **`os_login_admin_members`** so Terraform does not remove bindings on apply.

**GitHub Actions WIF:** one-time bootstrap outside CI (see workflow comments). If you rename the repo, update WIF bindings manually or via a local **`terraform apply`** with owner credentials — not from the CI service account.

See repository **`README.md`** for the full homelab layout.
