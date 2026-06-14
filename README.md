# homelab

Personal homelab: **`infra/`** (Terraform / GCP) + **`config/`** (Ansible for cloud and home hosts). GCP uses Cloud NAT + IAP; Tailscale is optional on home hosts only.

| Path | Purpose |
|------|---------|
| **`infra/`** | GCP VPC, VMs, IAP, OS Login, Cloud NAT — `terraform init`, `plan`, `apply` here |
| **`config/`** | Ansible converge for **`gcp_lab`** and **`home_lab`** hosts (see **`config/README.md`**) |
| **`docs/networking.md`** | **Networking (Cloud NAT, IAP, SSH)** |
| **`docs/tottipi-services.md`** | **Services on `tottipi` (inventory + dependencies)** |
| **`docs/ci-self-hosted-runner.md`** | **CI Ansible converge (GitHub-hosted, IAP)** |

## Quick start

**Terraform (GCP):**

```bash
cd infra
cp terraform.tfvars.example terraform.tfvars   # edit project / IAP principals
terraform init
terraform plan
```

**Ansible (after `terraform apply`):** see **`config/README.md`** (OS Login + playbooks).

**Existing VM on Tailscale?** **`docs/networking.md#offboard-from-tailscale`**

## What's in the lab

Hosts, egress, and SSH: **`docs/networking.md`**.

## CI

| Job | Runner | Notes |
|-----|--------|-------|
| Terraform plan/apply | GitHub **`ubuntu-latest`** + WIF | Unchanged |
| Ansible **`gcp_lab`** converge | GitHub **`ubuntu-latest`** + IAP | No **`tottipi`** dependency |

See **`docs/ci-self-hosted-runner.md`**. **`tottipi`** services: **`docs/tottipi-services.md`**.

**`home_lab`** converge: laptop (`ansible-playbook site.yml --limit home_lab`).

## Clone

```bash
git clone git@github.com:adamfriedl/homelab.git
cd homelab
```

## Repo layout note

**`.git` lives at the repo root** so **`infra/`** and **`config/`** stay in one place.

## Shared VPC snapshot (advanced)

Older two-project layouts may still exist only on **`lab/shared-vpc`** in Git history. Default **`main`** is single-project Terraform under **`infra/`**.
