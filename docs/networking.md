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
                   │         │  exit-node → tottipi (outbound + control plane)
                   └────┬────┘
                        │ Tailscale SSH (admin, steady state)
                        ▼
                    your laptop
```

| Host / path | Steady state |
|-------------|----------------|
| **`gcp-lab-1`** | Private `e2-micro`; **`tailscale ssh`** for admin (exit node on) |
| **`tottipi`** | Home Pi; **`tailscale ssh`**; future public edge |
| **GCP ↔ home (mesh)** | Tailscale peer traffic — no Cloud NAT |
| **GCP outbound internet** | Via **`tottipi`** (`tailscale_exit_node: tottipi`) — **required** |
| **Cloud NAT** | **Off** (`enable_cloud_nat = false`) — saves ~$30/mo |
| **Public ingress (planned)** | Cloudflare Tunnel on **`tottipi`**, not open GCP ports |

Full Ansible layout: **`config/README.md`** § Layout.

## Exit node: advertise vs use

Two different Tailscale flags — do not conflate them.

| Flag | Set on | Meaning |
|------|--------|---------|
| **`tailscale_advertise_exit_node`** | **`tottipi`** only | “Others may route internet through me.” |
| **`tailscale_exit_node: tottipi`** | **`gcp_lab`** | “Route *my* outbound through **`tottipi`**.” |

**Never** set **`tailscale_advertise_exit_node`** on GCP — breaks GCP metadata routing badly.

**Do** set **`tailscale_exit_node: tottipi`** on GCP. Without it, turning Cloud NAT off leaves **`tailscaled`** with no path to `controlplane.tailscale.com` and the node shows **offline**.

**Tradeoff:** with exit node on, **IAP SSH does not work reliably** on GCE (see Admin SSH). We accept that — steady-state admin is **`tailscale ssh`**, not IAP.

| File (under `config/inventory/group_vars/`) | Purpose |
|---------------------------------------------|---------|
| **`home_lab/tailscale.yml`** | `tailscale_advertise_exit_node: true` |
| **`gcp_lab/tailscale.yml`** | `tailscale_exit_node: tottipi` |
| **`gcp_lab/tailscale_secrets.yml`** | Auth key (gitignored); mirror in GitHub **`TAILSCALE_AUTH_KEY`** for CI — keep both in sync |

Approve **`tottipi`** as an exit node in [Tailscale Machines](https://login.tailscale.com/admin/machines) (or ACL **`autoApprovers.exitNode`**) before bootstrapping GCP.

## Bootstrap (fresh GCP VM)

The VM has **no internet** until Cloud NAT is on. **`tottipi`** must already be on the tailnet, advertising an exit node, and **approved** in admin.

```bash
# 0. Home first (if not already converged)
cd config && ansible-playbook site.yml --limit home_lab

# 1. Temporary egress for apt + initial tailnet join
# infra/terraform.tfvars → enable_cloud_nat = true
cd infra && terraform apply

# 2. Join tailnet + set exit-node=tottipi (gcp_lab/tailscale.yml)
cd ../config && ansible-playbook site.yml --limit gcp_lab

# 3. Verify (tailscale ssh — IAP may already be broken once exit-node is set)
tailscale ssh YOUR_OS_LOGIN_USER@gcp-lab-1 -- \
  'sudo tailscale status; curl -s --max-time 5 -o /dev/null -w "controlplane: %{http_code}\n" https://controlplane.tailscale.com'

# Expect: node online, tottipi active as exit node, controlplane HTTP 2xx/3xx.

# 4. Steady state
# infra/terraform.tfvars → enable_cloud_nat = false
cd ../infra && terraform apply

# 5. Re-verify over tailnet only (no IAP, no NAT)
tailscale ssh YOUR_OS_LOGIN_USER@gcp-lab-1 -- 'sudo tailscale status | head -8'
```

Use the OS Login username from **`gcloud compute os-login describe-profile`** (e.g. `ajfriedl_gmail_com`).

### If the node is offline after step 4

You turned NAT off before exit-node was applied, or **`tottipi`** was down/unapproved. Recovery:

1. `enable_cloud_nat = true` → `terraform apply`
2. `ansible-playbook site.yml --limit gcp_lab`
3. Verify (step 3 above, via **`tailscale ssh`**)
4. `enable_cloud_nat = false` → `terraform apply`

Remove stale Tailscale machine entries in the admin console after a VM rebuild.

## Admin SSH

Exit node sends GCP-bound traffic (including **169.254.169.254** metadata) through Tailscale paths Google does not expect. The kernel logs **martian source** errors; **IAP TCP forwarding to `:22` fails** even when **`sshd` is listening**.

| Method | When | **`gcp-lab-1`** |
|--------|------|-----------------|
| **`tailscale ssh USER@gcp-lab-1`** | **Steady state** (exit node on) | ✅ **Use this** |
| **`gcloud compute ssh --tunnel-through-iap`** | Bootstrap/recovery **before** exit node is set; or temporarily clear exit node | ✅ Only then |
| **Console SSH (browser button)** | — | ❌ Unreliable with exit node — [tailscale#11740](https://github.com/tailscale/tailscale/issues/11740) |

Example steady-state admin:

```bash
tailscale ssh ajfriedl_gmail_com@gcp-lab-1
```

**CI note:** GitHub Actions converges **`gcp_lab`** via **IAP** today — **broken in steady state**. Plan: self-hosted runner on **`tottipi`** + SSH over tailnet. Sketch: **`docs/ci-self-hosted-runner.md`**.

## Terraform knobs

| Variable | Steady state | Purpose |
|----------|--------------|---------|
| **`enable_external_public_ip`** | `false` | Private IP only |
| **`enable_cloud_nat`** | `false` | Bootstrap only; no ~$30/mo NAT charge |

Template: **`infra/terraform.tfvars.example`**. Include your user and CI SA in **`iap_ssh_tunnel_members`** and **`os_login_admin_members`** so apply does not drop IAM bindings.

## GCP gotchas

**Exit node vs IAP:** Using **`tottipi`** as exit node is required for NAT-off operation. It breaks IAP — do not rely on **`gcloud compute ssh --tunnel-through-iap`** while exit node is enabled.

**Reverse-path filtering:** GCP sets `rp_filter=1` (strict). Exit nodes can worsen routing issues. Tailscale recommends `rp_filter=2` in `/etc/sysctl.d/60-gce-network-security.conf` — see [Tailscale GCP reference](https://tailscale.com/docs/reference/reference-architectures/gcp). Not yet automated in Ansible.

## Related docs

- **`config/README.md`** — Ansible inventory, OS Login, playbook commands
- **`infra/README.md`** — Terraform workflow, WIF
- **`docs/ci-self-hosted-runner.md`** — sketch: CI converge via runner on `tottipi`
- **`docs/tottipi-services.md`** — what runs on the Pi
- **`README.md`** — repo overview
