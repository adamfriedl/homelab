# Networking

When running, **`gcp-lab-1`** is a private GCP VM with **Cloud NAT** egress and **IAP** for admin SSH and Ansible.

**Current state: scaled to zero.** No VMs and no Cloud NAT by default, so the lab costs nothing while idle. The network, IAM, and BigQuery stay. To bring a VM back, change these defaults in `infra/variables.tf` in a PR (merging applies):

```hcl
instances        = { "gcp-lab-1" = {} }
enable_cloud_nat = true   # only if the VM needs outbound Internet (apt, pip, etc.)
```

Don't do this with a local `terraform.tfvars` alone: CI writes its own tfvars and applies the defaults on every merge to main, so it would destroy the VM (and its boot disk) again. CI skips `ansible-playbook` when there are no VMs.

## When a VM is running

```
        Internet
            │
            ▼
       ┌─────────┐
       │ Cloud   │
       │ NAT     │
       └────┬────┘
            ▼
       ┌─────────┐
       │gcp-lab-1│  IAP SSH (admin + CI)
       └─────────┘
```

| Path | Setting |
|------|---------|
| Egress | **`enable_cloud_nat = true`** |
| Admin SSH | **`gcloud compute ssh --tunnel-through-iap`** |
| Ansible | IAP `ProxyCommand` in **`config/inventory/group_vars/gcp_lab/iap_ssh.yml`** |

Example:

```bash
gcloud compute ssh ajfriedl_gmail_com@gcp-lab-1 \
  --zone=us-central1-c --project=gcp-lab-497423 --tunnel-through-iap
```

OS Login username: **`gcloud compute os-login describe-profile`**.

First-time setup: **`config/README.md`**.

## Terraform knobs

| Variable | Default |
|----------|--------------|
| **`enable_external_public_ip`** | `false` |
| **`enable_cloud_nat`** | `false` (turn on when a VM needs egress) |
| **`instances`** | `{}` (no VMs) |

Template: **`infra/terraform.tfvars.example`**. Include your user and CI SA in **`iap_ssh_tunnel_members`** and **`os_login_admin_members`**.

## Related

- **`config/README.md`** — Ansible
- **`docs/ci.md`** — GitHub Actions
- **`infra/README.md`** — Terraform
