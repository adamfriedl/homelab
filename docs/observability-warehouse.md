# Homelab observability warehouse

Plan for a free-tier BigQuery “poor man’s” data platform: billing + CI + host metrics in one dataset. Pick up here in a new session.

## Goals

- Learn DevOps/data patterns: IaC, batch loads, partitioned BQ tables, CI instrumentation
- Stay on GCP free tier (~$0 at lab scale)
- Fit the lab network model — see **`docs/networking.md`** (GCP-only; metrics from `gcp-lab-1` or CI)

## Architecture

```
                    ┌─────────────────────────────────┐
                    │  BigQuery dataset: homelab      │
                    │  (project: gcp-lab-497423)      │
                    └────────────▲──────────▲─────────┘
                                 │          │
         billing export (GCP)    │          │  batch insert / load
                                 │          │
                          ┌──────┴──────────┴──────┐
                          │      gcp-lab-1         │
                          │  (Cloud NAT)           │
                          │  optional metrics cron │
                          └────────────────────────┘
                                      ▲
GitHub Actions ── ci_runs ────────────┘ (WIF)
```

**Design rule:** prefer loaders that already have GCP auth (CI WIF, cron on `gcp-lab-1`). No home-lab collector required.

## Dataset and tables

**Dataset:** `homelab` (same project is fine for homelab).

| Table | Phase | Source | Loader |
|-------|-------|--------|--------|
| `billing_*` | 1 | GCP billing export (native) | Google |
| `ci_runs` | 2 | GitHub Actions | CI via `bq insert` (WIF → `terraform-ci@...`) |
| `host_metrics` | 3 | `gcp-lab-1` (and others later) | VM cron or GHA scheduled job |

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
| `host` | STRING | e.g. `gcp-lab-1` |
| `ts` | TIMESTAMP | partition |
| `cpu_pct` | FLOAT64 | optional v1 |
| `mem_avail_mb` | INT64 | |
| `disk_root_pct` | INT64 | |
| `load_1m` | FLOAT64 | |
| `uptime_sec` | INT64 | optional |

v1: simple shell/Python cron on **`gcp-lab-1`** posting to BQ, or a scheduled GitHub Actions job over IAP. Upgrade to Prometheus later if needed.

## Phases

### Phase 1 — Billing export + BQ module

- Terraform `infra/modules/bigquery` (or inline): dataset `homelab`, IAM
- Enable **billing export → BigQuery** (Console one-time or IaC if desired)
- Example SQL in docs for spend by service
- **No VM egress required**

### Phase 2 — `ci_runs`

- Append one row per workflow run from `plan-and-apply.yml`
- Grant CI SA `bigquery.dataEditor` on `homelab`, `bigquery.jobUser` at project
- Use existing WIF — **no SA JSON key in GitHub**
- `if: always()` step so failures are recorded too

### Phase 3 — `host_metrics`

- Ansible role on **`gcp_lab`**: collector cron + batch insert (or `bq load`)
- Optional `node_exporter` on the VM; keep volume low (hourly)
- Dedicated SA with minimal BQ IAM; prefer metadata/ADC on the VM over JSON keys if possible

### Phase 4 — dbt + Looker Studio (later)

- `dbt` on laptop or CI → `stg_*` → `mart_lab_health`
- Looker Studio dashboard: spend + CPU/disk + CI failures

## First PR scope (start here)

1. `infra/modules/bigquery` — dataset, `ci_runs` + empty `host_metrics` tables, IAM for user + `terraform-ci@`
2. Document billing export enablement + starter queries
3. `plan-and-apply.yml` — `ci_runs` insert on completion
4. `docs/observability-warehouse.md` — keep updated (this file)

**Not in PR 1:** collectors, GCS bucket, dbt, billing export Terraform (unless easy)

## Auth cheat sheet

| Actor | Method |
|-------|--------|
| GitHub Actions | Workload Identity Federation → `terraform-ci@...` |
| `gcp-lab-1` cron | VM SA or OS Login + minimal BQ roles (TBD in Phase 3) |
| Laptop | `gcloud auth login` / ADC |

## Free tier guards

- Partition all tables by date
- Set `maximum_bytes_billed` in dev queries
- Hourly metrics, not per-second
- GCS lifecycle delete raw files after 30d (when GCS added)
- No Dataflow, no streaming inserts, no Pub/Sub v1

## Deferred / dropped

- Home-lab collector on a Raspberry Pi (out of repo scope)
- Tailscale coupling for metrics scrape paths
- Dataflow, Pub/Sub log pipeline (v1)

## Optional later

- **Private Google Access** on VPC if `gcp-lab-1` must call `*.googleapis.com` without NAT
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

- One dashboard or query: host disk/CPU for `gcp-lab-1` + monthly spend

## Related docs

- **`docs/networking.md`** — Cloud NAT, IAP, SSH
- **`docs/ci.md`** — GitHub Actions CI
- **`README.md`** — homelab overview
- **`config/README.md`** — Ansible
- **`infra/README.md`** — Terraform workflow
