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
       │ tailscaled (mesh only — no exit node)
       │
       ▼
  home admin / future edge services
  (Cloudflare Tunnel, metrics, etc.)

  gcp-lab-1 ── Cloud NAT + IAP ── independent of tottipi
```

**`tottipi`** being down does **not** affect **`gcp-lab-1`** egress or CI.

## Service catalog

| Service | Status | How run | Managed in git | Required for |
|---------|--------|---------|----------------|--------------|
| **`tailscaled`** | ✅ Running | `apt` / Ansible | `config/roles/tailscale`, `home_lab/tailscale.yml` | Home mesh, `tailscale ssh` to Pi |
| **metrics collector** | 📋 Planned | cron on host | `docs/observability-warehouse.md` Phase 3 | BQ `host_metrics` |
| **Cloudflare Tunnel** | 📋 Future | TBD | — | Public ingress to home services |

**Observability** (`host_metrics`, alerts) tells you if services are healthy; **this doc** tells you what should exist and why.

## `tailscaled` (today)

| | |
|--|--|
| **Config** | `tailscale_advertise_exit_node: false` |
| **Converge** | `ansible-playbook site.yml --limit home_lab` |
| **Depends on** | Home ISP, Tailscale control plane |

See **`docs/networking.md`**.

## Not managed in this repo (yet)

Document anything you install manually here before it becomes a dependency:

| Item | Notes |
|------|-------|
| Other Docker containers | Add a catalog row + compose under `config/compose/` when introduced |

## Related docs

- **`docs/networking.md`** — Cloud NAT, IAP, admin SSH
- **`docs/ci.md`** — CI over IAP (no runner on Pi)
- **`docs/observability-warehouse.md`** — metrics collector on `tottipi` (Phase 3)
- **`config/README.md`** — Ansible `home_lab` converge
