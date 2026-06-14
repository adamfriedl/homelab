# homelab

Personal homelab: **`infra/`** (Terraform / GCP) + **`config/`** (Ansible for GCP VMs).

| Path | Purpose |
|------|---------|
| **`infra/`** | GCP VPC, VMs, IAP, OS Login, Cloud NAT |
| **`config/`** | Ansible converge for **`gcp_lab`** (see **`config/README.md`**) |
| **`docs/networking.md`** | Cloud NAT, IAP, SSH |
| **`docs/ci.md`** | GitHub Actions (Terraform + Ansible over IAP) |

## Quick start

```bash
cd infra
cp terraform.tfvars.example terraform.tfvars   # edit project / IAP principals
terraform init
terraform apply

gcloud compute os-login ssh-keys add --key-file=~/.ssh/google_compute_engine.pub

cd ../config
ansible-playbook site.yml
```

## CI

| Job | Runner |
|-----|--------|
| Terraform plan/apply | GitHub **`ubuntu-latest`** + WIF |
| Ansible converge | GitHub **`ubuntu-latest`** + IAP |

See **`docs/ci.md`**.

## Clone

```bash
git clone git@github.com:adamfriedl/homelab.git
cd homelab
```

## Repo layout note

**`.git` lives at the repo root** so **`infra/`** and **`config/`** stay in one place.
