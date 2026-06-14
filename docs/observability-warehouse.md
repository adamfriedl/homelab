# Homelab observability warehouse

Plan for a free-tier BigQuery “poor man’s” data platform: billing + CI + host metrics in one dataset. Pick up here in a new session.

## Goals

- Learn DevOps/data patterns: IaC, batch loads, partitioned BQ tables, CI instrumentation
- Stay on GCP free tier (~$0 at lab scale)
- Fit the lab network model — see **`docs/networking.md`** (`tottipi` collector; `gcp-lab-1` metrics via IAP or push agent)

## Architecture

```
                    ┌─────────────────────────────────┐
                    │  BigQuery dataset: homelab      │
                    │  (project: gcp-lab-497423)      │
                    └────────────▲──────────▲─────────┘
                                 │          │
         billing export (GCP)    │          │  batch insert / load
                                 │          │
┌──────────────┐   IAP or agent  ┌────────────────┐
│  gcp-lab-1   │◄───────────────│    tottipi     │
│  (Cloud NAT) │                 │  collector +   │
│  metrics     │                 │  bq loader     │
└──────────────┘                 └────────────────┘
                                      ▲
GitHub Actions ── ci_runs ────────────┘ (WIF, no VM)
```

**Design rule:** `tottipi` runs the collector and BQ loader. `gcp-lab-1` is a metrics source (IAP scrape or local agent push), not a BQ client.

## Dataset and tables

**Dataset:** `homelab` (same project is fine for homelab).

| Table | Phase | Source | Loader |
|-------|-------|--------|--------|
| `billing_*` | 1 | GCP billing export (native) | Google |
| `ci_runs` | 2 | GitHub Actions | CI via `bq insert` (WIF → `terraform-ci@...`) |
| `host_metrics` | 3 | `tottipi` + scrape `gcp-lab-1` | `tottipi` cron + SA key |

### `ci_runs` (sketch)

Partition on `recorded_at`.

| Column | Type | Notes |
|--------|------|-------|
| `run_id` | STRING | `github.run_id` |
| `workflow` | STRING | e.g. `plan-and-apply` |
| `conclusion` | STRING | success / failure / cancelled |
| `duration_sec` | INT64 | optional |
| `terraform_apply` | BOOL | optional |
| `recorded_at` | TIMESTAMP | partition |

### `host_metrics` (sketch)

Partition on `ts` (or `recorded_at`).

| Column | Type | Notes |
|--------|------|-------|
| `host` | STRING | `tottipi`, `gcp-lab-1` |
| `ts` | TIMESTAMP | partition |
| `cpu_pct` | FLOAT64 | optional v1 |
| `mem_avail_mb` | INT64 | |
| `disk_root_pct` | INT64 | |
| `load_1m` | FLOAT64 | |
| `uptime_sec` | INT64 | optional |

v1: simple shell/Python collector on `tottipi`; pull `gcp-lab-1` metrics over IAP or run `node_exporter` with remote write. Upgrade to Prometheus later if needed.

## Phases

### Phase 1 — Billing export + BQ module

- Terraform `infra/modules/bigquery` (or inline): dataset `homelab`, IAM
- Enable **billing export → BigQuery** (Console one-time or IaC if desired)
- Example SQL in docs for spend by service (prove NAT was ~$30 when enabled)
- **No VM egress required**

### Phase 2 — `ci_runs`

- Append one row per workflow run from `plan-and-apply.yml` (and optionally `ansible.yml`)
- Grant CI SA `bigquery.dataEditor` on `homelab`, `bigquery.jobUser` at project
- Use existing WIF — **no SA JSON key in GitHub**
- `if: always()` step so failures are recorded too

### Phase 3 — `host_metrics`

- Ansible on **`home_lab` only**: collector cron + nightly `bq load` (or batch insert)
- Optional `node_exporter` on both; reach `gcp-lab-1` from `tottipi` over IAP or agent push
- Dedicated SA `homelab-tottipi@...` with minimal BQ (+ optional GCS) IAM
- SA JSON key on Pi at `/etc/homelab/gcp-sa.json` (gitignored, Ansible vault optional)

### Phase 4 — dbt + Looker Studio (later)

- `dbt` on `tottipi` or laptop → `stg_*` → `mart_lab_health`
- Looker Studio dashboard: spend + CPU/disk + CI failures

## First PR scope (start here)

1. `infra/modules/bigquery` — dataset, `ci_runs` + empty `host_metrics` tables, IAM for user + `terraform-ci@`
2. Document billing export enablement + starter queries
3. `plan-and-apply.yml` — `ci_runs` insert on completion
4. `docs/observability-warehouse.md` — keep updated (this file)

**Not in PR 1:** collectors, GCS bucket, dbt, billing export Terraform (unless easy), anything requiring `gcp-lab-1` egress.

## Auth cheat sheet

| Actor | Method |
|-------|--------|
| GitHub Actions | Workload Identity Federation → `terraform-ci@...` |
| `tottipi` cron | Dedicated SA + `GOOGLE_APPLICATION_CREDENTIALS` JSON key (minimal roles) |
| Laptop | `gcloud auth login` / ADC |
| `gcp-lab-1` | **Not a BQ client** for this project |

## Free tier guards

- Partition all tables by date
- Set `maximum_bytes_billed` in dev queries
- Hourly metrics, not per-second
- GCS lifecycle delete raw files after 30d (when GCS added)
- No Dataflow, no streaming inserts, no Pub/Sub v1

## Deferred / dropped

- GCP networking patterns that conflict with **`docs/networking.md`** (e.g. Tailscale exit node on GCP)
- Collectors on `gcp-lab-1` pushing to GCS/BQ
- Dataflow, Pub/Sub log pipeline (v1)

## Optional later

- **Private Google Access** on VPC if `gcp-lab-1` must call `*.googleapis.com` without NAT
- **Cloudflare Tunnel** on `tottipi` (public edge; same box as collector)
- Join billing to custom labels as Terraform grows

## Open decisions (resolve in PR 1 if easy)

1. Billing export: Console click vs Terraform `google_billing_account_*` — Console OK for homelab
2. `ci_runs`: direct `bq insert` vs GCS + load job — **direct insert** at this volume
3. `host_metrics` v1: custom script vs `node_exporter` — **custom script** first

## Success criteria

After Phase 2:

- SQL: last 30 days spend by service (billing export)
- SQL: CI failure count last 7 days (`ci_runs`)

After Phase 3:

- One dashboard or query: host disk/CPU for both machines + monthly spend

## Related docs

- **`docs/networking.md`** — Cloud NAT, IAP, SSH
- **`docs/tottipi-services.md`** — what runs on the Pi (inventory)
- **`docs/ci.md`** — GitHub Actions CI
- **`README.md`** — homelab overview
- **`config/README.md`** — Ansible groups, secrets
- **`infra/README.md`** — Terraform workflow
