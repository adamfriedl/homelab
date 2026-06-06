# homelab

Personal homelab: **`infra/`** (Terraform / GCP) + **`config/`** (Ansible for cloud and home hosts). Tailscale is the mesh between them.

| Path | Purpose |
|------|---------|
| **`infra/`** | GCP VPC, VMs, IAP, OS Login — `terraform init`, `plan`, `apply` here |
| **`config/`** | Ansible converge for **`gcp_lab`** and **`home_lab`** hosts (see **`config/README.md`**) |

## Quick start

**Terraform (GCP):**

```bash
cd infra
cp terraform.tfvars.example terraform.tfvars   # edit project / IAP principals
terraform init
terraform plan
```

**Ansible (after `terraform apply`):**

```bash
cd config
cp inventory/group_vars/gcp_lab/tailscale_secrets.yml.example \
   inventory/group_vars/gcp_lab/tailscale_secrets.yml   # paste tskey-auth-…
ansible-playbook site.yml --limit gcp_lab    # cloud only
ansible-playbook site.yml --limit home_lab   # home only (e.g. tottipi)
ansible-playbook site.yml                    # everything (laptop on tailnet)
```

## What's in the lab

| Host | Role | Admin access |
|------|------|----------------|
| **`gcp-lab-1`** | Private GCP VM (`e2-micro`, no public IP) | **`gcloud compute ssh --tunnel-through-iap`** |
| **`tottipi`** | Home Raspberry Pi; future public edge | **`tailscale ssh adam@tottipi`** |

**Network today:**

- **Tailscale** — mesh between home and cloud (peer traffic; no NAT required).
- **Cloud NAT** — **off** in steady state (`enable_cloud_nat = false`). Saves ~$30/mo.
- **Bootstrap** — flip NAT on temporarily to `apt install` / join Tailscale on a fresh VM, then turn it off.
- **Public ingress (planned)** — Cloudflare Tunnel on **`tottipi`**, not open ports or GCP exit nodes.

**Do not** enable a Tailscale **exit node on GCP VMs** — it breaks GCP metadata routing and IAP SSH. See **`config/README.md`**.

## CI

GitHub Actions manages **`gcp_lab`** only (`--limit gcp_lab` via IAP + Workload Identity Federation). **`home_lab`** is converged from your laptop (or a future self-hosted runner on **`tottipi`**).

Tailscale auth key: repository secret **`TAILSCALE_AUTH_KEY`** for CI; same value in local **`tailscale_secrets.yml`** for laptop runs.

## Clone

```bash
git clone git@github.com:adamfriedl/homelab.git
cd homelab
```

## Repo layout note

**`.git` lives at the repo root** so **`infra/`** and **`config/`** stay in one place.

## Shared VPC snapshot (advanced)

Older two-project layouts may still exist only on **`lab/shared-vpc`** in Git history. Default **`main`** is single-project Terraform under **`infra/`**.
