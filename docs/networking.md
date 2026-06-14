# Networking

**`gcp-lab-1`**: private GCP VM with **Cloud NAT** egress and **IAP** for admin SSH and Ansible.

## Steady state

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

| Variable | Steady state |
|----------|--------------|
| **`enable_external_public_ip`** | `false` |
| **`enable_cloud_nat`** | `true` |

Template: **`infra/terraform.tfvars.example`**. Include your user and CI SA in **`iap_ssh_tunnel_members`** and **`os_login_admin_members`**.

## Related

- **`config/README.md`** — Ansible
- **`docs/ci.md`** — GitHub Actions
- **`infra/README.md`** — Terraform
