# homelab

Personal homelab: **`infra/`** (Terraform / GCP) + **`config/`** (Ansible for cloud and home hosts). Tailscale is the mesh between them.

| Path | Purpose |
|------|---------|
| **`infra/`** | GCP VPC, VMs, IAP, OS Login — `terraform init`, `plan`, `apply` here |
| **`config/`** | Ansible converge for **`gcp_lab`** and **`home_lab`** hosts (see **`config/README.md`**) |
| **`docs/networking.md`** | **Networking (Tailscale, NAT, bootstrap, SSH)** |

## Quick start

**Terraform (GCP):**

```bash
cd infra
cp terraform.tfvars.example terraform.tfvars   # edit project / IAP principals
terraform init
terraform plan
```

**Ansible (after `terraform apply`):** see **`config/README.md`** (secrets setup + playbooks).

**Fresh GCP VM?** **`docs/networking.md#bootstrap-fresh-gcp-vm`**

## What's in the lab

Hosts, egress, and SSH: **`docs/networking.md`**.

## CI

GitHub Actions manages **`gcp_lab`** only (`--limit gcp_lab` via IAP + Workload Identity Federation). **`home_lab`** is converged from your laptop (or a future self-hosted runner on **`tottipi`**).

Tailscale auth key: **`docs/networking.md`**

## Clone

```bash
git clone git@github.com:adamfriedl/homelab.git
cd homelab
```

## Repo layout note

**`.git` lives at the repo root** so **`infra/`** and **`config/`** stay in one place.

## Shared VPC snapshot (advanced)

Older two-project layouts may still exist only on **`lab/shared-vpc`** in Git history. Default **`main`** is single-project Terraform under **`infra/`**.
