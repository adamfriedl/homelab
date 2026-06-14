# Networking

**`gcp-lab-1`** is a private GCP VM: **Cloud NAT** for egress, **IAP** for admin SSH and Ansible.

## Steady state

```
        Internet
            │
            ▼
       ┌─────────┐
       │ Cloud   │
       │ NAT     │
       └────┬────┘
            │ egress
            ▼
       ┌─────────┐
       │gcp-lab-1│  private IP, no public IP
       │         │  IAP SSH for admin + CI
       └─────────┘
```

| Path | Steady state |
|------|----------------|
| **GCP outbound internet** | **Cloud NAT** (`enable_cloud_nat = true`) |
| **Admin / Ansible SSH** | **IAP** + OS Login |
| **Public ingress** | Not open on GCP (future edge services elsewhere if needed) |

Ansible layout: **`config/README.md`**.

## Admin SSH

| Method | **`gcp-lab-1`** |
|--------|-----------------|
| **`gcloud compute ssh --tunnel-through-iap`** | ✅ **Use this** |
| **`ansible gcp_lab -m ping`** | ✅ IAP `ProxyCommand` in **`iap_ssh.yml`** |

Example:

```bash
gcloud compute ssh ajfriedl_gmail_com@gcp-lab-1 \
  --zone=us-central1-c --project=gcp-lab-497423 --tunnel-through-iap
```

OS Login username from **`gcloud compute os-login describe-profile`**.

## New VM

```bash
cd infra && terraform apply

gcloud compute os-login ssh-keys add --key-file=~/.ssh/google_compute_engine.pub

cd ../config && ansible-playbook site.yml
```

## Terraform knobs

| Variable | Steady state | Purpose |
|----------|--------------|---------|
| **`enable_external_public_ip`** | `false` | Private IP only |
| **`enable_cloud_nat`** | `true` | Outbound internet |

Template: **`infra/terraform.tfvars.example`**. Include your user and CI SA in **`iap_ssh_tunnel_members`** and **`os_login_admin_members`**.

## CI

GitHub Actions converges **`gcp_lab`** on **`ubuntu-latest`** over IAP. See **`docs/ci.md`**.

## Related docs

- **`config/README.md`** — Ansible inventory and playbooks
- **`infra/README.md`** — Terraform workflow, WIF
- **`README.md`** — repo overview
