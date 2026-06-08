# Networking

Single source of truth for how **`gcp-lab-1`**, **`tottipi`**, Tailscale, and Cloud NAT fit together.

## Steady state

```
                    Internet
                        │
                        ▼
                   ┌─────────┐
                   │ tottipi │  home ISP, advertises exit node
                   └────┬────┘
                        │ Tailscale (WireGuard)
                        ▼
                   ┌─────────┐
                   │gcp-lab-1│  private GCP VM, no public IP, no Cloud NAT
                   └────┬────┘
                        │ IAP (admin SSH only)
                        ▼
                    your laptop
```

| Host / path | Steady state |
|-------------|----------------|
| **`gcp-lab-1`** | Private `e2-micro`; admin via IAP SSH only |
| **`tottipi`** | Home Pi; admin via Tailscale SSH; future public edge |
| **GCP ↔ home (mesh)** | Tailscale peer traffic — no Cloud NAT |
| **GCP outbound internet** | Via **`tottipi`** (`tailscale_exit_node: tottipi`) |
| **Cloud NAT** | **Off** (`enable_cloud_nat = false`) — saves ~$30/mo |
| **Public ingress (planned)** | Cloudflare Tunnel on **`tottipi`**, not open GCP ports |

Full Ansible layout: **`config/README.md`** § Layout.

## Exit node: advertise vs use

Two different Tailscale flags — do not conflate them.

| Flag | Set on | Meaning |
|------|--------|---------|
| **`tailscale_advertise_exit_node`** | **`tottipi`** only | “Others may route internet through me.” |
| **`tailscale_exit_node: tottipi`** | **`gcp_lab`** | “Route *my* outbound through **`tottipi`**.” |

**Never** set **`tailscale_advertise_exit_node`** on GCP — breaks metadata routing and admin SSH paths.

**Do** set **`tailscale_exit_node: tottipi`** on GCP. Without it, turning Cloud NAT off leaves **`tailscaled`** with no path to `controlplane.tailscale.com` and the node shows **offline** in the admin console.

| File (under `config/inventory/group_vars/`) | Purpose |
|---------------------------------------------|---------|
| **`home_lab/tailscale.yml`** | `tailscale_advertise_exit_node: true` |
| **`gcp_lab/tailscale.yml`** | `tailscale_exit_node: tottipi` |
| **`gcp_lab/tailscale_secrets.yml`** | Auth key (gitignored); mirror in GitHub **`TAILSCALE_AUTH_KEY`** for CI — keep both in sync |

Approve **`tottipi`** as an exit node in [Tailscale Machines](https://login.tailscale.com/admin/machines) (or ACL **`autoApprovers.exitNode`**) before bootstrapping GCP.

## Bootstrap (fresh GCP VM)

The VM has **no internet** until Cloud NAT is on. **`tottipi`** must already be on the tailnet and advertising an exit node.

```bash
# 0. Home first (if not already converged)
cd config && ansible-playbook site.yml --limit home_lab

# 1. Temporary egress for apt + initial tailnet join
# infra/terraform.tfvars → enable_cloud_nat = true
cd infra && terraform apply

# 2. Join tailnet + set exit-node=tottipi (gcp_lab/tailscale.yml)
cd ../config && ansible-playbook site.yml --limit gcp_lab

# 3. Verify (via IAP — do not skip)
gcloud compute ssh gcp-lab-1 --zone=YOUR_ZONE --tunnel-through-iap -- \
  'sudo tailscale status; curl -s --max-time 5 -o /dev/null -w "controlplane: %{http_code}\n" https://controlplane.tailscale.com'

# Expect: node Online, tottipi listed as active exit node, controlplane HTTP 200/301/etc.

# 4. Steady state
# infra/terraform.tfvars → enable_cloud_nat = false
cd ../infra && terraform apply
```

### If the node is offline after step 4

You turned NAT off before exit-node was applied. Recovery:

1. `enable_cloud_nat = true` → `terraform apply`
2. `ansible-playbook site.yml --limit gcp_lab`
3. Verify (step 3 above)
4. `enable_cloud_nat = false` → `terraform apply`

Remove stale Tailscale machine entries (e.g. old **`gcp-lab-1`**) in the admin console after a VM rebuild.

## Admin SSH

| Method | **`gcp-lab-1`** | Notes |
|--------|-----------------|-------|
| **`gcloud compute ssh --tunnel-through-iap`** | ✅ Use this | Inbound to private IP:22; works with exit-node set |
| **Console SSH (browser button)** | ⚠️ Unreliable | Exit-node routing can block metadata — [tailscale#11740](https://github.com/tailscale/tailscale/issues/11740) |
| **`tailscale ssh`** | ❌ Avoid | Unreliable on cloud nodes |

## Terraform knobs

| Variable | Steady state | Purpose |
|----------|--------------|---------|
| **`enable_external_public_ip`** | `false` | Private IP only |
| **`enable_cloud_nat`** | `false` | Bootstrap only; no ~$30/mo NAT charge |

Template: **`infra/terraform.tfvars.example`**. Include your user and CI SA in **`iap_ssh_tunnel_members`** and **`os_login_admin_members`** so apply does not drop IAM bindings.

## GCP gotchas

**Reverse-path filtering:** GCP sets `rp_filter=1` (strict). Using an exit node can break egress until relaxed. Set `rp_filter=2` in `/etc/sysctl.d/60-gce-network-security.conf` before enabling exit node — see [Tailscale GCP reference](https://tailscale.com/docs/reference/reference-architectures/gcp). Not yet automated in Ansible.

## Related docs

- **`config/README.md`** — Ansible inventory, OS Login, playbook commands
- **`infra/README.md`** — Terraform workflow, WIF
- **`README.md`** — repo overview
