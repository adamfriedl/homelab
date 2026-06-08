# `tottipi` services

Inventory of what runs on the home Pi — **source of truth for intended state**. Git-managed services get Ansible or compose here; ad-hoc containers do not.

**Host:** Ubuntu 22.04 LTS, **aarch64**, Docker installed. Reachable via Tailscale / LAN (`config/inventory/home_lab.yml`).

## Dependency map (steady state)

```
Internet (home ISP)
       │
       ▼
  ┌─────────┐
  │ tottipi │
  └────┬────┘
       │ tailscaled (exit node, approved in admin)
       ├──────────────────────────────────────┐
       │                                      │
       ▼                                      ▼
  gcp-lab-1                           GitHub (hosted)
  exit-node egress                    Terraform plan/apply (WIF)
  tailnet SSH admin                   (no tottipi required)
       ▲
       │ tailnet SSH :22 (CI converge via github-runner)
       │
  github-runner on tottipi (Docker, host network)
```

If **`tottipi`** or its exit node is down, **`gcp-lab-1`** loses outbound/control-plane path (NAT off) and CI converge stops.

## Service catalog

| Service | Status | How run | Managed in git | Required for |
|---------|--------|---------|----------------|--------------|
| **`tailscaled`** | ✅ Running | `apt` / Ansible | `config/roles/tailscale`, `home_lab/tailscale.yml` | Mesh, exit node, `tailscale ssh` |
| **`github-runner`** | ✅ Ansible-managed | Docker (`network_mode: host`) | `config/compose/tottipi/github-runner/`, `roles/github_runner` | CI Ansible `--limit gcp_lab` |
| **metrics collector** | 📋 Planned | cron on host | `docs/observability-warehouse.md` Phase 3 | BQ `host_metrics` |
| **Cloudflare Tunnel** | 📋 Future | TBD | — | Public ingress to tailnet backends |

**Observability** (`host_metrics`, alerts) tells you if services are healthy; **this doc** tells you what should exist and why.

## `tailscaled` (today)

| | |
|--|--|
| **Config** | `tailscale_advertise_exit_node: true` |
| **Admin** | Approve exit node in [Tailscale Machines](https://login.tailscale.com/admin/settings/keys) |
| **Converge** | `ansible-playbook site.yml --limit home_lab` |
| **Depends on** | Home ISP, Tailscale control plane |

See **`docs/networking.md`** § Exit node.

## `github-runner`

| | |
|--|--|
| **Why** | Hosted GH Actions uses IAP for Ansible; IAP breaks when **`gcp-lab-1`** has exit node on |
| **Labels** | `homelab`, `tottipi` |
| **Network** | Docker **`network_mode: host`** — uses host Tailscale routes to reach `gcp-lab-1` |
| **Compose** | **`config/compose/tottipi/github-runner/`** |
| **Converge** | `ansible-playbook site.yml --limit home_lab` (after one-time GitHub registration) |
| **Design** | **`docs/ci-self-hosted-runner.md`** |

Do not `docker run` the runner by hand without adding a row here and a compose file in the repo.

## Not managed in this repo (yet)

Document anything you install manually here before it becomes a dependency:

| Item | Notes |
|------|-------|
| Other Docker containers | Add a catalog row + compose under `config/compose/tottipi/` (path TBD) when introduced |

## Related docs

- **`docs/networking.md`** — NAT, exit node, bootstrap, admin SSH
- **`docs/ci-self-hosted-runner.md`** — runner implementation sketch
- **`docs/observability-warehouse.md`** — metrics collector on `tottipi` (Phase 3)
- **`config/README.md`** — Ansible `home_lab` converge
