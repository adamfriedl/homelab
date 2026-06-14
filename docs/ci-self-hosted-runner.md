# CI: Ansible over IAP (GitHub-hosted)

**`gcp_lab` Ansible converge** runs on **`ubuntu-latest`** with IAP SSH — no dependency on **`tottipi`** or Tailscale.

## Architecture

```
GitHub (hosted)                         gcp-lab-1
┌─────────────────────────┐            ┌─────────────┐
│ plan-or-apply           │── WIF ────►│ Cloud NAT   │
│ ubuntu-latest           │            │ IAP :22     │
└─────────────────────────┘            └──────▲──────┘
┌─────────────────────────┐                  │
│ ansible job             │── IAP tunnel ────┘
│ ubuntu-latest           │   OS Login key
│ WIF + gcloud + Ansible  │
└─────────────────────────┘
```

Both jobs use WIF. Terraform manages infra; Ansible converges over **`config/inventory/group_vars/gcp_lab/iap_ssh.yml`**.

## What's in git

| Path | Purpose |
|------|---------|
| **`config/inventory/group_vars/gcp_lab/iap_ssh.yml`** | Default Ansible SSH (IAP `ProxyCommand`) |
| **`config/inventory/group_vars/gcp_lab/ssh_common.yml`** | OS Login user + default key path |
| **`.github/actions/ansible-gcp-bootstrap`** | WIF, terraform init, ephemeral OS Login key |
| **`.github/workflows/plan-and-apply.yml`** | Terraform + Ansible jobs |

## Self-hosted runner (deprecated)

The **`tottipi`** GitHub runner existed only because GCP used **`tottipi`** as a Tailscale exit node, which broke IAP. That coupling is removed.

| Item | Action |
|------|--------|
| **`github_runner_enabled`** | `false` in **`home_lab/github_runner.yml`** |
| Runner in GitHub UI | Remove **`tottipi`** under Settings → Actions → Runners |
| Compose on Pi | Optional: `docker compose down` in **`config/compose/tottipi/github-runner/`** |

Legacy compose docs remain under **`config/compose/tottipi/github-runner/`** if you want a runner for other jobs later.

## CI service account on OS Login

Converge mints an RSA key and runs `gcloud compute os-login ssh-keys add`. **`terraform-ci@…`** must stay in **`os_login_admin_members`** and **`iap_ssh_tunnel_members`**.

## Related

- **`docs/networking.md`** — Cloud NAT, IAP admin SSH
- **`docs/tottipi-services.md`** — home Pi services (independent of GCP)
