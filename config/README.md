# `config/` — Ansible

Ansible converges **GCP VMs** (Terraform under **`infra/`**) and **home-lab hosts** (static inventory). Both sit in the **`lab`** group and run from **`site.yml`**.

**Networking (Cloud NAT, IAP, SSH):** **`docs/networking.md`**  
**`tottipi` services:** **`docs/tottipi-services.md`**

| Group | Hosts | Reachable from (steady state) | CI |
|-------|-------|-------------------------------|-----|
| **`gcp_lab`** | `gcp-lab-1`, … | **IAP SSH** (see **`docs/networking.md`**) | GitHub **`ubuntu-latest`** (IAP) |
| **`home_lab`** | `tottipi`, … | Tailscale / LAN | No (laptop); services: **`docs/tottipi-services.md`** |

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

   Set **`gcp_lab_ansible_user`** in **`inventory/group_vars/gcp_lab/ssh_common.yml`**.

2. **Offboard from Tailscale** (if VM was previously on the tailnet) — **`docs/networking.md#offboard-from-tailscale`**

## One-time wiring (home lab)

**Tailscale auth key** (optional, for **`home_lab`** only) — reusable `tskey-auth-…` from [Tailscale Keys](https://login.tailscale.com/admin/settings/keys):

```bash
cp inventory/group_vars/home_lab/tailscale_secrets.yml.example \
   inventory/group_vars/home_lab/tailscale_secrets.yml
```

```bash
ansible-playbook bootstrap-home-sudo.yml --ask-become-pass
```

Writes **`/etc/sudoers.d/<user>-ansible`** on **`home_lab`** hosts so **`become: true`** works.

## Run

```bash
ansible-playbook site.yml --limit gcp_lab     # cloud (CI does this)
ansible-playbook site.yml --limit home_lab    # home
ansible-playbook site.yml                     # all
ansible gcp_lab -m ping
ansible home_lab -m ping
```

## Tailscale role

Runs on **`home_lab`** when auth key or exit-node prefs are set. **Not used on `gcp_lab`.** Policy: **`docs/networking.md`**.

## Layout

| Path | Role |
|------|------|
| **`ansible.cfg`** | Merged inventory: Terraform script + **`home_lab.yml`** |
| **`inventory/terraform_inventory.py`** | Dynamic **`gcp_lab`** |
| **`inventory/home_lab.yml`** | Static **`home_lab`** |
| **`inventory/group_vars/gcp_lab/ssh_common.yml`** | OS Login user + default key path |
| **`inventory/group_vars/gcp_lab/iap_ssh.yml`** | IAP SSH (steady state) |
| **`inventory/group_vars/home_lab/connection.yml`** | SSH user / options for home |
| **`inventory/group_vars/home_lab/tailscale.yml`** | Tailscale prefs (no exit node) |
| **`inventory/group_vars/home_lab/tailscale_secrets.yml.example`** | → **`tailscale_secrets.yml`** (gitignored) |
| **`inventory/group_vars/home_lab/github_runner.yml`** | Runner role (disabled by default) |
| **`offboard-gcp-tailscale.yml`** | One-time Tailscale removal on GCP |
| **`bootstrap-home-sudo.yml`** | One-time sudo for **`home_lab`** |
| **`site.yml`** | Entry playbook |
| **`roles/common`** | Baseline sanity |
| **`roles/tailscale`** | Install, join, prefs |
| **`roles/github_runner`** | Docker Actions runner on **`home_lab`** (optional) |
| **`compose/tottipi/github-runner/`** | Runner compose + registration docs |

## Secrets

**`home_lab/tailscale_secrets.yml`** is gitignored. Optionally Ansible Vault-encrypt for defense in depth.
