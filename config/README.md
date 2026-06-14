# `config/` — Ansible

Ansible converges **GCP VMs** provisioned by Terraform under **`infra/`**. Inventory is dynamic from **`terraform output -json`**.

**Networking (Cloud NAT, IAP, SSH):** **`docs/networking.md`**

## Inventory

```bash
export GCP_LAB_TERRAFORM_DIR=/absolute/path/to/infra   # optional override
ansible-inventory --list --yaml
ansible-inventory --graph gcp_lab
```

Hosts land in group **`gcp_lab`** (child of **`lab`** in the dynamic inventory script).

## One-time wiring

After **`terraform apply`**:

```bash
gcloud compute os-login ssh-keys add --key-file=~/.ssh/google_compute_engine.pub
gcloud compute os-login describe-profile --format='value(posixAccounts[0].username)'
```

Set **`gcp_lab_ansible_user`** in **`inventory/group_vars/gcp_lab/ssh_common.yml`**.

## Run

```bash
ansible-playbook site.yml              # all gcp_lab hosts
ansible-playbook site.yml --limit gcp_lab
ansible gcp_lab -m ping
```

CI runs the same converge on merge to **`main`** (see **`docs/ci.md`**).

## Layout

| Path | Role |
|------|------|
| **`ansible.cfg`** | Dynamic Terraform inventory |
| **`inventory/terraform_inventory.py`** | **`gcp_lab`** from Terraform outputs |
| **`inventory/group_vars/gcp_lab/ssh_common.yml`** | OS Login user + default key path |
| **`inventory/group_vars/gcp_lab/iap_ssh.yml`** | IAP SSH (`ProxyCommand`) |
| **`site.yml`** | Entry playbook |
| **`roles/common`** | Baseline sanity (`uptime`) |

## What converge does today

**`site.yml`** runs the **`common`** role only: confirm the host is reachable over IAP and print uptime. Add roles here as you install software on **`gcp-lab-1`**.
