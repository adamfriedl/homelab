# `config/` — Ansible

Ansible drives the GCP VM Terraform creates under **`infra/`**. With the default IAP-only stance (no public IP), **`gcloud`** must be on your **`PATH`** and **`gcloud auth login`** (or equivalent) must work — same expectation as **`gcloud compute ssh --tunnel-through-iap`**.

## How inventory lines up with Terraform

**Inventory is dynamic:** `inventory/terraform_inventory.py` runs **`terraform output -json`** against **`../infra/`** (configurable override below). It emits the **`gcp_lab`** group with:

- **`gcp_project_id`**, **`gcp_zone`** from Terraform outputs (**`project_id`**, **`zone`** in **`infra/outputs.tf`**).
- The single host **`instance_name`** from Terraform.

Keep **`infra/` applied** at least once so those outputs exist. After you change **`instance_name`** / **`project_id`** / **`zone`** and **`terraform apply`**, Ansible picks up new values automatically — **no Ansible inventory edits.**

**Manual override:** if Terraform lives elsewhere:

```bash
export GCP_LAB_TERRAFORM_DIR=/absolute/path/to/infra
ansible-inventory --list    # cwd = config/
```

## One-time wiring

1. **Preflight SSH** — uses **`gcloud`**, not Terraform `application-default` alone:

   ```bash
   cd ../infra
   terraform output ssh_via_iap_gcloud
   # Run the printed gcloud compute ssh ... --tunnel-through-iap command.
   ```

   If that fails, fix IAP / OS Login / firewall before Ansible.

2. **Remote user:** Debian on GCE often expects the Unix name tied to your login (OS Login) or whatever **`gcloud compute ssh`** uses. If Ansible fails with “permission denied”, set **`ansible_user`** in **`inventory/group_vars/gcp_lab.yml`** or pass **`-u yourname`** to **`ansible-playbook`**.

## Run

Working directory **`config/`** (loads **`ansible.cfg`**):

```bash
ansible-playbook site.yml
```

Quick check (`ansible.cfg` inventory is used):

```bash
ansible gcp_lab -m ping
```

Debug inventory:

```bash
ansible-inventory --list --yaml
```

### Static fallback (no Terraform locally)

Example only: **`inventory/hosts.yml.example`**. Copy patterns there and point Ansible at **`hosts.yml`** (or pass **`-i`**) plus set **`gcp_project_id`** / **`gcp_zone`** via **`inventory/group_vars`** or **`-e`**.

## Layout

| Path | Role |
|------|------|
| **`ansible.cfg`** | **`inventory`** = Terraform-backed script |
| **`inventory/terraform_inventory.py`** | Executable: **`terraform output -json`** → Ansible JSON |
| **`inventory/group_vars/gcp_lab.yml`** | IAP `ProxyCommand`; optional **`ansible_user`** |
| **`site.yml`** | Entry playbook |
| **`roles/common`** | Starter role (baseline sanity tasks) |

## Secrets / Vault

Keep secrets out of Git (API keys, join tokens). Use Ansible Vault or **`--extra-vars`** / env for sensitive values once you add them.
