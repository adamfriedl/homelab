# homelab

Personal homelab: **`infra/`** (Terraform / GCP) + **`config/`** (Ansible for GCP VMs).

| Path | Purpose |
|------|---------|
| **`infra/`** | GCP VPC, VMs, IAP, OS Login, Cloud NAT |
| **`config/`** | Ansible converge — see **`config/README.md`** |
| **`docs/networking.md`** | Cloud NAT, IAP, SSH |
| **`docs/ci.md`** | GitHub Actions |

## Quick start

See **`config/README.md`** for OS Login setup and **`infra/README.md`** for Terraform.

```bash
cd infra && cp terraform.tfvars.example terraform.tfvars && terraform init && terraform apply
cd ../config && ansible-playbook site.yml
```

## Clone

```bash
git clone git@github.com:adamfriedl/homelab.git
cd homelab
```
