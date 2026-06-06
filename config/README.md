# `config/` — Ansible

Ansible converges **GCP VMs** (Terraform under **`infra/`**) and **home-lab hosts** (static inventory). Both sit in the **`lab`** group and run from **`site.yml`**.

| Group | Hosts | Reachable from | CI |
|-------|-------|----------------|-----|
| **`gcp_lab`** | `gcp-lab-1`, … | IAP (`gcloud`) | Yes |
| **`home_lab`** | `tottipi`, … | Tailscale / LAN | No (laptop or future self-hosted runner) |

## Inventory

**GCP (dynamic):** `inventory/terraform_inventory.py` → **`terraform output -json`** → **`gcp_lab`** under **`lab`**.

**Home (static):** `inventory/home_lab.yml` — machines Terraform does not own.

```bash
export GCP_LAB_TERRAFORM_DIR=/absolute/path/to/infra   # optional override
ansible-inventory --list --yaml
```

## One-time wiring (GCP)

1. **OS Login + IAP SSH** — after **`terraform apply`**:

   ```bash
   gcloud compute os-login ssh-keys add --key-file=~/.ssh/google_compute_engine.pub
   gcloud compute os-login describe-profile --format='value(posixAccounts[0].username)'
   ```

   Set **`ansible_user`** in **`inventory/group_vars/gcp_lab/iap_ssh.yml`**.

2. **Tailscale auth key** — create a **reusable** `tskey-auth-…` at [Tailscale Keys](https://login.tailscale.com/admin/settings/keys). Put it in **both**:

   - **`inventory/group_vars/gcp_lab/tailscale_secrets.yml`** (laptop Ansible; gitignored)
   - GitHub secret **`TAILSCALE_AUTH_KEY`** (CI converge)

   Keep them in sync. CI does not read the local file; your laptop does not read GitHub secrets.

3. **Fresh VM bootstrap** — no internet egress until Tailscale joins:

   ```bash
   # infra/terraform.tfvars
   enable_cloud_nat = true
   terraform apply
   cd ../config && ansible-playbook site.yml --limit gcp_lab
   # infra/terraform.tfvars
   enable_cloud_nat = false
   terraform apply
   ```

## One-time wiring (home lab)

```bash
ansible-playbook bootstrap-home-sudo.yml --ask-become-pass
```

Writes **`/etc/sudoers.d/<user>-ansible`** on **`home_lab`** hosts so **`become: true`** works.

## Run

```bash
ansible-playbook site.yml --limit gcp_lab     # cloud (CI does this)
ansible-playbook site.yml --limit home_lab    # home
ansible-playbook site.yml                     # all (laptop on tailnet)
ansible gcp_lab -m ping
ansible home_lab -m ping
```

## Egress and networking

### GCP VM (`gcp-lab-1`)

| Setting | Steady state |
|---------|----------------|
| Public IP | No (`enable_external_public_ip = false`) |
| Cloud NAT | **Off** (`enable_cloud_nat = false`) |
| Tailscale exit node on VM | **Never** — breaks metadata + IAP |
| General internet (`apt`, `curl`) | No, unless NAT temporarily on |
| Tailscale mesh | Yes — peer traffic to **`tottipi`** etc. |
| Admin SSH | **IAP only** — `gcloud compute ssh --tunnel-through-iap` |

### Home (`tottipi`)

**`inventory/group_vars/home_lab/tailscale.yml`** sets **`tailscale_advertise_exit_node: true`**. Approve in [Tailscale Machines](https://login.tailscale.com/admin/machines) (or ACL **`autoApprovers.exitNode`**) if you want **`tottipi`** as an exit node for **laptops/phones** — not for routing the GCP VM's default route.

**Planned public edge:** Cloudflare Tunnel + reverse proxy on **`tottipi`**, proxying to backends on the tailnet (including **`gcp-lab-1`**). See repo root **`README.md`**.

### How to reach hosts

| Host | Use | Avoid |
|------|-----|-------|
| **`gcp-lab-1`** | `gcloud compute ssh … --tunnel-through-iap` | `tailscale ssh` (unreliable on cloud nodes) |
| **`tottipi`** | `tailscale ssh adam@tottipi` | — |

## Tailscale role

Installs **`tailscaled`**, joins with **`tailscale up --auth-key=…`**, applies prefs via **`tailscale set`** on re-runs.

**Home-only without auth key:** runs when **`tailscale_advertise_exit_node`** is set (advertise exit node on **`tottipi`**).

**GCP:** requires **`tailscale_auth_key`** (local file or **`-e`** / CI secret).

Copy the example:

```bash
cp inventory/group_vars/gcp_lab/tailscale_secrets.yml.example \
   inventory/group_vars/gcp_lab/tailscale_secrets.yml
```

## Layout

| Path | Role |
|------|------|
| **`ansible.cfg`** | Merged inventory: Terraform script + **`home_lab.yml`** |
| **`inventory/terraform_inventory.py`** | Dynamic **`gcp_lab`** |
| **`inventory/home_lab.yml`** | Static **`home_lab`** |
| **`inventory/group_vars/gcp_lab/iap_ssh.yml`** | IAP `ProxyCommand` |
| **`inventory/group_vars/gcp_lab/tailscale_secrets.yml.example`** | → **`tailscale_secrets.yml`** (gitignored) |
| **`inventory/group_vars/home_lab/connection.yml`** | SSH user / options for home |
| **`inventory/group_vars/home_lab/tailscale.yml`** | Advertise exit node on **`tottipi`** |
| **`bootstrap-home-sudo.yml`** | One-time sudo for **`home_lab`** |
| **`site.yml`** | Entry playbook |
| **`roles/common`** | Baseline sanity |
| **`roles/tailscale`** | Install, join, prefs |

## Secrets

**`tailscale_secrets.yml`** is gitignored. Optionally Ansible Vault-encrypt for defense in depth.
