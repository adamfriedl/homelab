# CI: self-hosted runner on `tottipi`

**`gcp_lab` Ansible converge** runs on a self-hosted runner because steady-state exit node breaks IAP.

## Problem

| Job | Runner | Steady state |
|-----|--------|--------------|
| Terraform plan/apply | `ubuntu-latest` + WIF | ✅ Unchanged |
| Ansible `--limit gcp_lab` | **`tottipi`** (labels `homelab`, `tottipi`) | Tailnet SSH → `gcp-lab-1:22` |

Ansible must run from a host **on the tailnet** — same path as admin SSH over MagicDNS, not IAP.

## Architecture

```
GitHub (hosted)                    tottipi (self-hosted)              gcp-lab-1
┌─────────────────┐               ┌──────────────────────┐           ┌─────────────┐
│ plan-or-apply   │── WIF ───────►│ (terraform on GH)    │           │ exit node   │
│ ubuntu-latest   │               │                      │           │ → tottipi   │
└─────────────────┘               └──────────────────────┘           └──────▲──────┘
                                  ┌──────────────────────┐                  │
                                  │ converge job         │── tailnet SSH ───┘
                                  │ Docker runner        │   OS Login :22
                                  │ network_mode: host   │
                                  └──────────────────────┘
```

**Split workflows** (`.github/workflows/plan-and-apply.yml`):

1. **`plan-or-apply`** — `ubuntu-latest` + WIF → GCP APIs.
2. **`converge`** — `runs-on: [self-hosted, homelab, tottipi]`; WIF + `gcloud` for OS Login key; Ansible over tailnet.

## What's in git

| Path | Purpose |
|------|---------|
| **`config/compose/tottipi/github-runner/`** | Docker Compose (`network_mode: host`), `.env.example`, registration README |
| **`config/roles/github_runner`** | Deploy compose to `/opt/homelab/github-runner` via `site.yml --limit home_lab` |
| **`config/inventory/group_vars/gcp_lab/tailnet_ssh.yml`** | Default Ansible SSH (MagicDNS `gcp-lab-1`) |
| **`config/extras/gcp_lab_iap_bootstrap.yml`** | Bootstrap only — `-e @extras/gcp_lab_iap_bootstrap.yml` when NAT on / no exit node |
| **`config/inventory/group_vars/gcp_lab/ssh_common.yml`** | OS Login user + default key path |

Do **not** run `tailscaled` only inside the runner container — host networking uses the Pi's existing tailnet routes.

## One-time: register the runner

1. GitHub → **Settings → Actions → Runners → New self-hosted runner** → copy registration token.
2. On your laptop:

   ```bash
   cp config/compose/tottipi/github-runner/.env.example \
      config/compose/tottipi/github-runner/.env
   # edit RUNNER_TOKEN=…
   cd config && ansible-playbook site.yml --limit home_lab
   ```

3. Confirm runner online in GitHub; remove **`RUNNER_TOKEN`** from `.env` (state persists in **`data/`** on `tottipi`).

## Ansible SSH (`gcp_lab`)

**Steady state** — `tailnet_ssh.yml` (auto-loaded):

```yaml
ansible_host: gcp-lab-1
ansible_ssh_common_args: >-
  -o IdentitiesOnly=yes
  -o StrictHostKeyChecking=accept-new
```

**Bootstrap** (NAT on, exit node not set):

```bash
ansible-playbook site.yml --limit gcp_lab -e @extras/gcp_lab_iap_bootstrap.yml
```

CI passes `-e @/tmp/ci-tailnet-ssh.yml` with the ephemeral OS Login key from **`terraform-ci@…`**.

### CI service account on OS Login

Converge mints an RSA key and runs `gcloud compute os-login ssh-keys add`. That key works over **tailnet SSH** — OS Login does not require IAP. **`terraform-ci@…`** must stay in **`os_login_admin_members`**.

## Converge job (implemented)

See **`.github/workflows/plan-and-apply.yml`** — `converge` job:

- `runs-on: [self-hosted, homelab, tottipi]`
- WIF auth + `setup-gcloud` + `terraform init` (inventory script)
- OS Login key for CI SA
- `ansible-playbook site.yml --limit gcp_lab` with `ansible_host: gcp-lab-1`

**Removed:** IAP tunnel, `127.0.0.1:8222` hop.

## Prerequisites on `tottipi`

- **`tailscaled`** joined and stable (exit node approved)
- **Docker** + compose plugin (runner container)
- Converge jobs install **Python/Ansible/gcloud/terraform** per run via Actions (no host pinning required)

WIF works on self-hosted runners (`permissions: id-token: write`).

## Rollout checklist

1. ✅ Compose + Ansible role in git
2. ✅ `tailnet_ssh.yml` + IAP bootstrap extra
3. ✅ `converge` job on self-hosted runner
4. **You:** register runner (above) before merging workflow to `main`
5. **You:** verify converge after merge (`tailscale ping gcp-lab-1` from Pi if debugging)

## Security notes

- Self-hosted runner = **trust boundary** — merge to `main` runs code on `tottipi`. Fine for personal homelab; add environment protection if that changes.
- Label runner **`tottipi`** so only converge jobs land there — Terraform stays on hosted runners.

## Related

- **`docs/networking.md`** — exit node vs IAP; steady-state admin via `tailscale ssh`
- **`docs/tottipi-services.md`** — service inventory on the Pi
- **`docs/observability-warehouse.md`** — metrics collector (same box)
