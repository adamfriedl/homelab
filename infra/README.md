# Terraform (`infra/`)

Run Terraform **from this directory** so relative module paths (`./modules/…`) resolve:

```bash
cd infra
terraform init
terraform plan
```

Use **`terraform.tfvars.example`** as the template for **`terraform.tfvars`** (ignored by `.gitignore`).

See repository README for **`gcp-lab/`** layout and the parked **`lab/shared-vpc`** branch note.
