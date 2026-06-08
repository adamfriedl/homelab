# CI: self-hosted runner on `tottipi`

Sketch for fixing **`gcp_lab` Ansible converge** after steady-state exit node breaks IAP.

## Problem

| Job | Today | Steady state |
|-----|-------|--------------|
| Terraform plan/apply | `ubuntu-latest` + WIF | ✅ Keep as-is |
| Ansible `--limit gcp_lab` | `ubuntu-latest` + IAP tunnel → `:22` | ❌ IAP fails when exit node on |

Ansible must run from a host **on the tailnet** that SSHes to **`gcp-lab-1`** over Tailscale — same path as `tailscale ssh`, not IAP.

## Target architecture

```
GitHub (hosted)                    tottipi (self-hosted)              gcp-lab-1
┌─────────────────┐               ┌──────────────────────┐           ┌─────────────┐
│ plan-or-apply   │── WIF ───────►│ GCP APIs (terraform) │           │ exit node   │
│ ubuntu-latest   │               │ (optional mirror)    │           │ → tottipi   │
└─────────────────┘               └──────────────────────┘           └──────▲──────┘
                                  ┌──────────────────────┐                  │
                                  │ converge job         │── tailnet SSH ───┘
                                  │ runner (labels:      │   MagicDNS / 100.x
                                  │  homelab, tottipi)    │   port 22, OS Login
                                  └──────────────────────┘
```

**Split workflows:**

1. **`plan-or-apply`** — unchanged on `ubuntu-latest` (needs WIF → GCP APIs).
2. **`converge`** — `runs-on: [self-hosted, homelab, tottipi]`; drop IAP tunnel; SSH to `gcp-lab-1` via tailnet.

## Docker or native?

| Approach | Pros | Cons |
|----------|------|------|
| **Native runner (systemd)** | Simplest on Pi; uses host `tailscale` + `tailscale ssh` CLI; no ARM image hunt | Runner deps on host Python/Ansible |
| **Docker `network_mode: host`** | Isolated runner version; easy recreate | Still depends on **host** Tailscale (don't run tailscaled only in container without host net) |
| **Docker with tailscale in container** | "Pure" container | Pain on Pi (UDP, `/dev/net/tun`, state); not worth it for homelab |

**Recommendation:** start **native systemd runner** on `tottipi`. Add Docker later only if you want pinning — use **`network_mode: host`**, Tailscale stays on the Pi OS.

```yaml
# Later, if you dockerize — host network is the point
services:
  github-runner:
    image: ghcr.io/actions/actions-runner:latest   # check arm64 availability
    network_mode: host
    environment:
      RUNNER_NAME: tottipi
      RUNNER_LABELS: homelab,tottipi
      # registration via entrypoint + PAT/registration token
    volumes:
      - ./runner-data:/home/runner
```

Do **not** put `tailscaled` only inside the container without host networking — Ansible needs to reach `100.x.x.x` / MagicDNS on the tailnet interface the Pi already has.

## Ansible connection change (`gcp_lab`)

Today (`iap_ssh.yml`): `ProxyCommand=gcloud … start-iap-tunnel …`

**Steady-state CI / tailnet converge** (new file, e.g. `tailnet_ssh.yml`):

```yaml
# Used when runner/laptop is on the tailnet (exit node safe).
ansible_host: gcp-lab-1          # MagicDNS short name
ansible_user: "{{ gcp_lab_ansible_user }}"   # OS Login user, e.g. terraform-ci_… or ajfriedl_gmail_com
ansible_ssh_private_key_file: ~/.ssh/ci_oslogin   # or dedicated converge key
ansible_ssh_common_args: >-
  -o IdentitiesOnly=yes
  -o StrictHostKeyChecking=accept-new
  -o ProxyCommand=none
```

SSH goes to **`gcp-lab-1:22` over the tailnet** — regular `sshd` + OS Login, not IAP, not the `tailscale ssh` subcommand. Exit node on GCP does not break this (inbound tailnet → `:22`).

**Keep `iap_ssh.yml` for bootstrap** when NAT is on and you temporarily clear exit node, or use `-e` / group var toggle:

```yaml
# group_vars/gcp_lab/connection.yml (future)
gcp_lab_ssh_method: tailnet   # tailnet | iap
```

Inventory merge or `ansible.cfg` `group_vars` priority picks `iap_ssh` vs `tailnet_ssh`.

### CI service account on OS Login

Converge job already mints an RSA key and runs `gcloud compute os-login ssh-keys add` for **`terraform-ci@…`**. That same key works over **tailnet SSH** to port 22 — OS Login does not require IAP.

Ensure **`terraform-ci@…`** is in **`os_login_admin_members`** (already is).

## Workflow sketch (`converge` job)

```yaml
converge:
  name: Ansible converge (tailnet)
  needs: plan-or-apply
  if: github.event_name == 'push' && github.ref == 'refs/heads/main'
  runs-on: [self-hosted, homelab, tottipi]
  steps:
    - uses: actions/checkout@v5

    # Optional: terraform output for inventory script (no WIF if state readable locally)
    - uses: hashicorp/setup-terraform@v4
    - run: terraform init -input=false
      working-directory: infra

    - uses: actions/setup-python@v6
      with:
        python-version: "3.12"
    - run: pip install ansible-core

    - name: OS Login key for CI SA
      # gcloud auth: use stored key on tottipi OR workload identity if you wire it
      run: |
        # ssh-keygen + os-login ssh-keys add (same as today)
        # write ansible_user + key path to GITHUB_OUTPUT

    - name: ansible-playbook site.yml
      working-directory: config
      env:
        TAILSCALE_AUTH_KEY: ${{ secrets.TAILSCALE_AUTH_KEY }}
      run: |
        ansible-playbook site.yml --limit gcp_lab \
          -e @/tmp/ci-tailnet-ssh.yml
        # optionally: --limit home_lab (tottipi is localhost-ish; may skip)
```

**Remove:** IAP tunnel, `127.0.0.1:8222` hop.

## Runner install on `tottipi` (native, one-time)

From GitHub: **Settings → Actions → Runners → New self-hosted runner** → Linux arm64.

```bash
# on tottipi (user with docker optional; runner as dedicated user recommended)
sudo useradd -m -s /bin/bash github-runner
sudo mkdir -p /opt/actions-runner && sudo chown github-runner: /opt/actions-runner
# download arm64 runner tarball from GitHub, extract to /opt/actions-runner
sudo -u github-runner ./config.sh --url https://github.com/adamfriedl/homelab \
  --token REGISTRATION_TOKEN --labels homelab,tottipi --unattended

# systemd unit (GitHub provides svc.sh install)
sudo ./svc.sh install github-runner
sudo ./svc.sh start
```

**Prerequisites on `tottipi`:**

- `tailscale` joined, stable
- `gcloud` + application credentials for **`terraform-ci`** (for OS Login key ops only), **or** pre-provision a long-lived converge SSH key on `gcp-lab-1`
- `python3`, `pip`, `git`, `jq`
- Read access to Terraform state (local mirror of GCS backend **or** `gcloud auth` + `terraform init` with same backend as CI)

## Secrets / auth on the Pi

| Need | Option A (simple) | Option B (cleaner) |
|------|-------------------|---------------------|
| Register runner | GitHub registration token (ephemeral) | Same |
| `TAILSCALE_AUTH_KEY` | GitHub secret → env in job | Same |
| OS Login key install | `gcloud` as SA JSON key on Pi (`/etc/homelab-ci/key.json`) | Pre-sync key once via Ansible |
| Terraform state for inventory | `terraform init` with GCS backend + SA key | Copy `terraform output` from apply job artifact |

Hosted **`plan-or-apply`** can upload **`terraform output` JSON** as artifact; **`converge`** on `tottipi` downloads it — avoids duplicating GCS/state creds on the Pi if you prefer.

## Rollout phases

1. **Register runner** on `tottipi`; test with a noop workflow (`runs-on: tottipi`, `tailscale ping gcp-lab-1`).
2. **Add `tailnet_ssh.yml`** + manual `ansible-playbook` from `tottipi` shell (prove OS Login over tailnet).
3. **Move `converge` job** off `ubuntu-latest`; delete IAP tunnel steps.
4. **Document bootstrap** — IAP Ansible only when NAT on / exit node not yet set (`docs/networking.md`).
5. **(Optional)** Docker wrapper with `network_mode: host` once native path is boring.

## Security notes

- Self-hosted runner = **trust boundary** — anyone with merge to main can run code on `tottipi`. Fine for personal homelab; use **environment protection** or **branch rules** if that changes.
- Runner user should **not** be root; sudo only where Ansible `become` needs it (same as today on GCP via OS Login admin).
- Label runner **`tottipi`** so only converge jobs land there — keep Terraform on hosted runners.

## Related

- **`docs/networking.md`** — exit node vs IAP; steady-state admin via `tailscale ssh`
- **`docs/tottipi-services.md`** — service inventory and dependencies on the Pi
- **`config/inventory/group_vars/gcp_lab/iap_ssh.yml`** — bootstrap / legacy path
- **`docs/observability-warehouse.md`** — `tottipi` as home worker (same box as runner + collector)
