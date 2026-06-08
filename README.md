# homelab

Personal homelab: **`infra/`** (Terraform / GCP) + **`config/`** (Ansible for cloud and home hosts). Tailscale is the mesh between them.

| Path | Purpose |
|------|---------|
| **`infra/`** | GCP VPC, VMs, IAP, OS Login — `terraform init`, `plan`, `apply` here |
| **`config/`** | Ansible converge for **`gcp_lab`** and **`home_lab`** hosts (see **`config/README.md`**) |
| **`docs/networking.md`** | **Networking (Tailscale, NAT, bootstrap, SSH)** |
| **`docs/tottipi-services.md`** | **Services on `tottipi` (inventory + dependencies)** |
| **`docs/ci-self-hosted-runner.md`** | **CI Ansible converge via self-hosted runner** |

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

| Job | Runner | Notes |
|-----|--------|-------|
| Terraform plan/apply | GitHub **`ubuntu-latest`** + WIF | Unchanged |
| Ansible **`gcp_lab`** converge | Self-hosted on **`tottipi`** | IAP broken in steady state (exit node on GCP) |

See **`docs/ci-self-hosted-runner.md`**. **`tottipi`** services and deps: **`docs/tottipi-services.md`**. Networking: **`docs/networking.md`**.

**`home_lab`** converge: laptop only today (`ansible-playbook site.yml --limit home_lab`).

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
