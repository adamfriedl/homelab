# `config/` — Ansible

Ansible converges **GCP VMs** from Terraform. Inventory is dynamic via **`terraform output -json`**.

**Networking:** **`docs/networking.md`** · **CI:** **`docs/ci.md`**

## One-time setup

After **`terraform apply`**:

```bash
gcloud compute os-login ssh-keys add --key-file=~/.ssh/google_compute_engine.pub
gcloud compute os-login describe-profile --format='value(posixAccounts[0].username)'
```

Set **`ansible_user`** in **`inventory/group_vars/gcp_lab/ssh_common.yml`** to match your OS Login username.

## Run

```bash
ansible-playbook site.yml
ansible gcp_lab -m ping
ansible-inventory --graph gcp_lab
```

## Layout

| Path | Role |
|------|------|
| **`inventory/terraform_inventory.py`** | Dynamic **`gcp_lab`** hosts from Terraform |
| **`inventory/group_vars/gcp_lab/ssh_common.yml`** | OS Login user + SSH key |
| **`inventory/group_vars/gcp_lab/iap_ssh.yml`** | IAP `ProxyCommand` |
| **`site.yml`** | Converge playbook (`uptime` sanity check today) |

Add tasks or roles to **`site.yml`** as you install software on **`gcp-lab-1`**.
