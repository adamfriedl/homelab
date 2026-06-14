# Networking

How **`gcp-lab-1`** and **`tottipi`** connect — **GCP uses Cloud NAT + IAP; Tailscale is home-lab only.**

## Steady state

```
                    Internet
                        │
          ┌─────────────┴─────────────┐
          │                           │
          ▼                           ▼
     ┌─────────┐                 ┌─────────┐
     │ tottipi │                 │ Cloud   │
     │ (home)  │                 │ NAT     │
     └────┬────┘                 └────┬────┘
          │ Tailscale (optional)      │ GCP egress
          │ mesh only                 ▼
          │                      ┌─────────┐
          └──── (no exit node)   │gcp-lab-1│  private VM, no public IP
                                 │         │  IAP SSH for admin + CI
                                 └─────────┘
```

| Host / path | Steady state |
|-------------|----------------|
| **`gcp-lab-1`** | Private `e2-micro`; **IAP SSH** for admin and Ansible |
| **`tottipi`** | Home Pi; Tailscale for home mesh only (no exit node) |
| **GCP outbound internet** | **Cloud NAT** (`enable_cloud_nat = true`) |
| **GCP ↔ home** | **Not coupled** — no Tailscale on GCP, no exit node on `tottipi` |
| **Public ingress (planned)** | Cloudflare Tunnel on **`tottipi`**, not open GCP ports |

Full Ansible layout: **`config/README.md`** § Layout.

## Admin SSH

| Method | When | **`gcp-lab-1`** |
|--------|------|-----------------|
| **`gcloud compute ssh --tunnel-through-iap`** | **Steady state** | ✅ **Use this** |
| **`ansible gcp_lab -m ping`** | Laptop / CI | ✅ IAP `ProxyCommand` in **`iap_ssh.yml`** |
| **`tailscale ssh`** | Home hosts only | ❌ Not on GCP |

Example:

```bash
gcloud compute ssh ajfriedl_gmail_com@gcp-lab-1 \
  --zone=us-central1-c --project=gcp-lab-497423 --tunnel-through-iap
```

OS Login username from **`gcloud compute os-login describe-profile`**.

## Fresh GCP VM

With Cloud NAT on from the start, there is no Tailscale bootstrap dance:

```bash
# 1. Terraform (NAT on)
cd infra && terraform apply

# 2. OS Login key (one-time)
gcloud compute os-login ssh-keys add --key-file=~/.ssh/google_compute_engine.pub

# 3. Converge
cd ../config && ansible-playbook site.yml --limit gcp_lab
```

## Offboard from Tailscale (existing VM)

If **`gcp-lab-1`** was previously joined to the tailnet with **`tailscale_exit_node: tottipi`**, IAP is broken until you clear that. Recovery:

```bash
# 1. Ensure NAT is on (terraform.tfvars → enable_cloud_nat = true)
cd infra && terraform apply

# 2. Strip Tailscale from the VM
cd ../config
ansible-playbook offboard-gcp-tailscale.yml --limit gcp_lab \
  -e @extras/gcp_lab_tailnet_offboard_ssh.yml   # if IAP still broken; omit once IAP works

# 3. Steady-state converge (no Tailscale role on gcp_lab)
ansible-playbook site.yml --limit gcp_lab
```

Remove stale **`gcp-lab-1`** entries in [Tailscale Machines](https://login.tailscale.com/admin/machines) after offboarding.

## Terraform knobs

| Variable | Steady state | Purpose |
|----------|--------------|---------|
| **`enable_external_public_ip`** | `false` | Private IP only |
| **`enable_cloud_nat`** | `true` | Outbound internet for apt, tailscale join (if ever needed), control plane |

Template: **`infra/terraform.tfvars.example`**. Include your user and CI SA in **`iap_ssh_tunnel_members`** and **`os_login_admin_members`**.

## CI

GitHub Actions converges **`gcp_lab`** on **`ubuntu-latest`** over IAP — no self-hosted runner on **`tottipi`**. See **`.github/workflows/plan-and-apply.yml`**.

## Related docs

- **`config/README.md`** — Ansible inventory, OS Login, playbook commands
- **`infra/README.md`** — Terraform workflow, WIF
- **`docs/tottipi-services.md`** — what runs on the Pi
- **`README.md`** — repo overview
