# Terraform (`infra/`)

Run Terraform **from this directory** so relative module paths (`./modules/…`) resolve:

```bash
cd infra
terraform init
terraform plan
```

**Egress:** with **`enable_external_public_ip = false`**, VMs need **`enable_cloud_nat = true`** (default) so outbound HTTPS (**`apt`**, Tailscale repos) leaves the VPC. Turning NAT off implies you rely on something else for SNAT.

Use **`terraform.tfvars.example`** as the template for **`terraform.tfvars`** (ignored by `.gitignore`).

See repository README for **`gcp-lab/`** layout and the parked **`lab/shared-vpc`** branch note.
