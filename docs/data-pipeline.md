# Film Permits Pipeline — Full Plan

A step-by-step guide to learning Airflow, BigQuery, and Looker Studio by building a real (but small) data pipeline on your homelab GCP project.

**Repo roles:** platform = **`infra/`** (BigQuery tables, IAM); application = **`pipelines/`** (DAGs, SQL). See **`docs/repo-layout.md`**.

Read this top to bottom once, then treat each phase as a checklist you work through in order.

---

## The elevator pitch

We're going to:

1. Pull **NYC film permit** data from the city's open data API
2. Load it into **BigQuery** in your `gcp-lab` project
3. Clean and summarize it with SQL
4. Orchestrate the whole thing with **Airflow** running on your MacBook
5. Build a **Looker Studio** dashboard on top

When you're done, you'll have touched every layer of a modern analytics stack — extract, load, transform, orchestrate, visualize — without spending meaningful money or running Airflow on an undersized VM.

---

## Why film permits?

We picked **[Film Permits](https://data.cityofnewyork.us/City-Government/Film-Permits/tg4x-b46p)** because it hits a sweet spot:

| Criterion | Film permits |
|-----------|--------------|
| Dedicated dataset | Yes — its own catalog page and API (`tg4x-b46p`) |
| Fun / quirky | NYC as a movie set; "Shooting Permit" means cameras, not guns |
| Actually revealing | TV dominates Manhattan/Brooklyn; you can see production patterns by borough and category |
| Right size | ~5,000 permits per year — big enough to need pagination, small enough to stay free |
| Still maintained | City updates it regularly |

**One dashboard footnote you'll want:** "Shooting Permit" = film/TV production. Not firearms. Future-you will thank present-you.

---

## What runs where

This is the most common point of confusion, so let's be explicit:

```
┌─────────────────────────────────────────────────────────────┐
│  YOUR MACBOOK                                                 │
│  • Airflow (scheduler + web UI)                              │
│  • DAG code (Python)                                         │
│  • Your gcloud credentials                                   │
│  Job: "run these steps in order, retry on failure"           │
└──────────────────────────┬──────────────────────────────────┘
                           │ HTTPS API calls
                           ▼
┌─────────────────────────────────────────────────────────────┐
│  NYC OPEN DATA (free, public)                                │
│  • SODA API at data.cityofnewyork.us                         │
│  Job: "here's JSON for film permits matching your filter"    │
└──────────────────────────┬──────────────────────────────────┘
                           │ Airflow fetches + loads
                           ▼
┌─────────────────────────────────────────────────────────────┐
│  GCP — gcp-lab project                                       │
│  • BigQuery dataset: homelab                                 │
│  • Tables: raw → stg → mart                                  │
│  Job: store data, run SQL transforms                         │
└──────────────────────────┬──────────────────────────────────┘
                           │ Looker Studio connects read-only
                           ▼
┌─────────────────────────────────────────────────────────────┐
│  LOOKER STUDIO (free, in browser)                            │
│  Job: charts and dashboards                                  │
└─────────────────────────────────────────────────────────────┘
```

**Your homelab VM (`gcp-lab-1`) is not involved.** It's an e2-micro — too small for Airflow. The VM stays for other homelab stuff (Ansible, future cron loaders, etc.).

---

## The data layers (medallion architecture)

We organize BigQuery tables in three layers. This pattern shows up everywhere in data engineering:

| Layer | Table | What's in it | Analogy |
|-------|-------|--------------|---------|
| **Raw** | `raw_film_permits` | Exactly what the API returned, plus a `loaded_at` timestamp | Photocopy of the source |
| **Staging** | `stg_film_permits` | Cleaned: deduped, null bad rows, filtered date range | Typed, spell-checked copy |
| **Mart** | `mart_film_permits_daily` | Aggregated for charts: daily counts by borough, category, event type | The slide deck |

Airflow runs tasks in that order. Each layer has a job:

- **Raw** — prove ingestion works; preserve history if you reload
- **Staging** — one place for data quality rules
- **Mart** — what Looker Studio reads (fast, simple queries)

---

## What the DAG does

The Airflow DAG is named **`nyc_film_permits`**. It's a recipe with five steps:

```
extract_and_load_raw
        ↓
transform_staging   (runs stg_film_permits.sql)
        ↓
transform_mart      (runs mart_film_permits_daily.sql)
```

**Step 1 — Extract & load:** Python code calls the NYC API in pages (10,000 rows at a time), filters to your date range, inserts into `raw_film_permits`.

**Step 2 — Staging SQL:** Dedupe on `eventid`, drop rows missing borough/category, keep only your date window.

**Step 3 — Mart SQL:** Roll up to daily counts: `permit_date × borough × category × eventtype`, plus parking-hold counts and top subcategory.

You'll trigger this manually at first (`schedule=None`). Once it works, you can schedule it weekly.

---

## Cost expectations

| Thing | Expected cost |
|-------|---------------|
| BigQuery storage (~5k rows) | $0 (free tier) |
| BigQuery queries (with byte limits) | $0 |
| Airflow on Mac | $0 |
| Looker Studio | $0 |
| Socrata API | $0 |
| Cloud Composer | **Not using it** (~$300+/mo) |

Stay under control by:

- Loading **one year** at a time (default: 2024)
- Filtering at the API (`$where` on `startdatetime`) — never pull the full 17k+ history until you mean to
- Setting **maximum bytes billed** in the BigQuery Console (e.g. 1 GB = ~$5 cap)

---

## Prerequisites

Before Phase 0, you should have:

- [ ] Homelab GCP project working (`gcp-lab-497423` or your equivalent)
- [ ] `gcloud` CLI installed and logged in
- [ ] Terraform applied at least once for VPC/VM (existing homelab setup)
- [ ] Python 3.10+ on your Mac
- [ ] This repo cloned locally

Nice to have (not required for v1):

- [ ] Socrata app token from [NYC Open Data developer settings](https://data.cityofnewyork.us/) — raises API rate limits
- [ ] Docker (alternative Airflow install path; we use `airflow standalone` in the plan below)

---

## Phase 0 — Create the BigQuery home

### What you're doing

Creating the `homelab` dataset and the `raw_film_permits` table in GCP via Terraform. Also granting yourself permission to read/write BigQuery.

### Why this step matters

Airflow needs somewhere to land data before it can transform anything. Defining the table in Terraform means your infrastructure is reproducible — you can tear down and recreate, and CI can manage it later.

### Steps

**Option A — merge via CI (recommended if `IAP_SSH_TUNNEL_MEMBER` is set in GitHub)**

CI writes `bigquery_data_editor_members` and `bigquery_job_user_members` from the same principals as IAP/OS Login (`IAP_SSH_TUNNEL_MEMBER` + `terraform-ci@…`). See **`docs/ci.md`**. Open a PR, merge to `main`, and CI apply creates the dataset, table, and your BigQuery IAM — no separate local apply required for access.

**Option B — local apply first**

1. Open `infra/terraform.tfvars` (copy from `terraform.tfvars.example` if you haven't).

2. Add your Google account to both lists (use your actual `@gmail.com` or workspace email):

   ```hcl
   bigquery_data_editor_members = [
     "user:you@gmail.com",
   ]
   bigquery_job_user_members = [
     "user:you@gmail.com",
   ]
   ```

3. Apply:

   ```bash
   cd infra
   terraform plan    # should show dataset + table + IAM
   terraform apply
   ```

4. Confirm:

   ```bash
   terraform output bigquery_raw_film_permits_table
   bq ls homelab
   ```

Keep local tfvars aligned with CI (same member lists) so shared remote state does not plan IAM removals on the next CI apply.

### How you know it worked

- `bq ls` shows dataset `homelab` and table `raw_film_permits`
- Terraform output looks like `gcp-lab-497423.homelab.raw_film_permits`

### What you learned

- BigQuery datasets and tables can be infrastructure-as-code
- You need both `dataEditor` (write tables) and `jobUser` (run queries) roles

---

## Phase 1 — Explore the data before you automate

### What you're doing

Looking at the source data with your eyes and a few curl commands. No Airflow yet.

### Why this step matters

Every data engineer who skips exploration regrets it. You'll see what fields exist, what weird values look like, and whether your date filter returns sensible row counts — before you write a DAG that fails mysteriously at 2am (or on a Saturday learning session).

### Steps

1. **One sample row:**

   ```bash
   curl -sS "https://data.cityofnewyork.us/resource/tg4x-b46p.json?\$limit=1" | python3 -m json.tool
   ```

   Look at: `eventtype`, `category`, `borough`, `startdatetime`, `parkingheld`.

2. **Count for 2024:**

   ```bash
   curl -sS "https://data.cityofnewyork.us/resource/tg4x-b46p.json?\$select=count(*)&\$where=startdatetime%20>=%20'2024-01-01T00:00:00'%20AND%20startdatetime%20<%20'2025-01-01T00:00:00'"
   ```

   Expect roughly **5,000** rows.

3. **Category breakdown (optional curiosity):**

   ```bash
   curl -sS "https://data.cityofnewyork.us/resource/tg4x-b46p.json?\$select=category,count(*)&\$group=category&\$order=count%20DESC"
   ```

   Television and Theater dominate. Good to know for your dashboard story.

4. **Browse in the portal:** [Film Permits on NYC Open Data](https://data.cityofnewyork.us/City-Government/Film-Permits/tg4x-b46p) — click around, read the data dictionary.

### How you know it worked

- Sample JSON parses cleanly
- 2024 count is in the thousands, not zero or millions
- You can explain to someone what a "Shooting Permit" row represents

### What you learned

- SODA API basics: `$limit`, `$where`, `$select`, `$group`
- The shape of the data you're about to pipeline

---

## Phase 2 — Authenticate your Mac to GCP

### What you're doing

Giving your local tools (Airflow, Python, `bq` CLI) permission to talk to your GCP project.

### Why this step matters

Airflow runs on your Mac but BigQuery runs in GCP. Application Default Credentials (ADC) bridge the two — same pattern you'd use for local dev against any cloud service.

### Steps

```bash
gcloud auth login                           # if not already
gcloud auth application-default login       # creates ADC file
gcloud config set project gcp-lab-497423    # your project ID
```

Test it:

```bash
bq query --use_legacy_sql=false 'SELECT 1 AS ok'
```

### How you know it worked

Query returns a row with `ok = 1`. No permission denied errors.

### What you learned

- `gcloud auth login` vs `application-default login` — the latter is what SDKs and Airflow use

---

## Phase 3 — Install and start Airflow locally

### What you're doing

Running the Airflow scheduler and web UI on your Mac. Pointing it at the DAG in `pipelines/dags/`.

### Why this step matters

This is the orchestration layer — the thing that says "first fetch, then transform staging, then transform mart" with retries and a UI to watch progress.

### Steps

1. **Optional: Socrata app token**

   - Register / sign in at [opendata.cityofnewyork.us](https://opendata.cityofnewyork.us/)
   - Profile → Developer Settings → Create App Token
   - Copy to `pipelines/.env` (from `.env.example`)

2. **Python environment:**

   ```bash
   cd pipelines
   python3 -m venv .venv
   source .venv/bin/activate
   pip install -r requirements.txt
   ```

3. **Environment variables:**

   ```bash
   export AIRFLOW_HOME=~/airflow-homelab
   export GCP_PROJECT_ID=gcp-lab-497423
   export BQ_DATASET_ID=homelab
   export SOCRATA_APP_TOKEN=your-token-here   # optional but recommended
   ```

4. **Initialize Airflow (first time only):**

   ```bash
   airflow db init
   ```

5. **Link DAGs:**

   ```bash
   mkdir -p "$AIRFLOW_HOME/dags"
   ln -sf "$(pwd)/dags" "$AIRFLOW_HOME/dags/homelab"
   ```

6. **Start Airflow:**

   ```bash
   airflow standalone
   ```

   This runs scheduler + webserver together. Note the admin password printed in the terminal.

7. **Open the UI:** http://localhost:8080

### How you know it worked

- UI loads
- DAG **`nyc_film_permits`** appears in the list (may take ~30 seconds)
- DAG graph shows: `extract_and_load_raw` → `render_staging_sql` → `transform_staging` → `render_mart_sql` → `transform_mart`

### What you learned

- Airflow is a process manager for data jobs, not a database
- DAGs are Python files in a folder — edit file, Airflow picks it up

---

## Phase 4 — Run the pipeline end to end

### What you're doing

Triggering the DAG manually and watching each task succeed. This is the main event.

### Why this step matters

You'll see the full ELT loop in action: API → raw table → SQL transforms → mart table. Everything after this is refinement.

### Steps

1. In the Airflow UI, open **`nyc_film_permits`**.

2. Click **Trigger DAG** (play button). Default params load **2024-01-01 through 2024-12-31**.

   To change the window: Trigger DAG w/ config → `{"start_date": "2024-06-01", "end_date": "2024-07-01"}` for a one-month test.

3. Watch tasks turn green one by one. If something fails, click the task → **Log**.

4. **Verify in BigQuery Console** (or CLI):

   ```sql
   -- Raw layer
   SELECT COUNT(*) FROM `gcp-lab-497423.homelab.raw_film_permits`;

   -- Staging
   SELECT COUNT(*) FROM `gcp-lab-497423.homelab.stg_film_permits`;

   -- Mart: the money query
   SELECT borough, category, SUM(permit_count) AS permits
   FROM `gcp-lab-497423.homelab.mart_film_permits_daily`
   GROUP BY 1, 2
   ORDER BY permits DESC;
   ```

   You should see Manhattan and Brooklyn high on TV/Film categories.

### How you know it worked

| Check | Expected |
|-------|----------|
| All DAG tasks green | ✓ |
| `raw_film_permits` row count | ~5,000 for full 2024 |
| `stg_film_permits` row count | Slightly less (bad rows filtered) |
| `mart_film_permits_daily` | Aggregated rows, not zero |
| Borough breakdown | Manhattan + Brooklyn dominate |

### What you learned

- **Extract:** paginated API → JSON → BigQuery insert
- **Transform:** SQL owns business logic, not Python
- **Orchestration:** Airflow wires dependencies and handles retries

### Common failures

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| 403 on BigQuery | Missing IAM roles | Ensure `IAP_SSH_TUNNEL_MEMBER` is set in GitHub (CI) or `bigquery_*_members` in local tfvars; re-apply |
| 401 / ADC error | No application-default creds | `gcloud auth application-default login` |
| 0 rows loaded | Wrong date params | Check `$where` dates match data (use Phase 1 count) |
| SODA timeout | No app token, throttled | Add `SOCRATA_APP_TOKEN` |
| Task red on staging SQL | Raw table empty | Fix extract first; check logs |

---

## Phase 5 — Build the Looker Studio dashboard

### What you're doing

Connecting a free Google dashboard tool to your mart table and making charts that tell a story.

### Why this step matters

The pipeline exists to answer questions. Looker Studio is how non-SQL humans (including future-you) consume the answers. Also: this completes the loop you set out to learn.

### Steps

1. Go to [lookerstudio.google.com](https://lookerstudio.google.com)

2. **Create → Report → BigQuery** connector

3. Select project `gcp-lab-497423`, dataset `homelab`, table **`mart_film_permits_daily`**

4. **Suggested charts:**

   | Chart type | Dimensions | Metric | Story |
   |------------|------------|--------|-------|
   | Time series | `permit_date` | `permit_count` | Production activity over the year |
   | Breakdown | `category` | `permit_count` | TV vs Film vs Commercial vs Theater |
   | Bar | `borough` | `permit_count` | Where filming happens |
   | Stacked bar | `borough` | `permit_count`, color by `eventtype` | Shooting vs rigging vs load-in |
   | Scorecard | — | `SUM(permit_count)` | Total permits in view |

5. **Add a text box:** explain that "Shooting Permit" means film production.

6. Add a **date range control** on `permit_date` so you can zoom into months.

7. Share the report link (optional).

### How you know it worked

- Charts render without errors
- Numbers match your BigQuery mart query from Phase 4
- You can answer: "Which borough had the most TV permits in 2024?"

### What you learned

- Marts exist to make BI easy — wide, aggregated, chart-ready
- Looker Studio reads BigQuery directly; no export step needed

---

## Phase 6 — Hardening (after v1 works)

Don't do this until Phase 4–5 succeed. These are the "real data engineering" upgrades:

| Upgrade | What it teaches |
|---------|-----------------|
| **Schedule the DAG** (`@weekly`) | Production operations |
| **Incremental loads** — merge on `eventid` instead of re-inserting | Idempotency |
| **Data quality checks** — assert row count > 0, no null boroughs | Testing in pipelines |
| **Load 2025 YTD** alongside 2024 | Multi-period backfill |
| **Add dbt** for transforms instead of raw SQL files | Modern transform layer |
| **Billing export** into same `homelab` dataset | Ties into observability warehouse plan |

See **`docs/observability-warehouse.md`** for adding homelab billing/CI metrics to the same dataset later.

---

## Repo map (where everything lives)

See **`docs/repo-layout.md`** for the platform vs application split.

```
homelab/
├── infra/                         ← platform: dataset + raw table + IAM
│   └── modules/bigquery/
├── pipelines/                     ← application: DAG + transform SQL
│   ├── dags/film_permits_dag.py
│   └── sql/
└── docs/
    ├── repo-layout.md
    └── data-pipeline.md             ← this document
```

---

## Glossary

| Term | Plain English |
|------|---------------|
| **Airflow** | Job scheduler with a web UI. Runs your pipeline steps in order. |
| **DAG** | Directed Acyclic Graph — the pipeline recipe. A list of tasks and their order. |
| **BigQuery** | Google's cloud data warehouse. Stores tables, runs SQL fast. |
| **SODA / Socrata** | The API NYC Open Data uses. You HTTP GET JSON from it. |
| **Extract** | Pull data from a source (the API). |
| **Load** | Write data into a warehouse (BigQuery raw table). |
| **Transform** | Clean and aggregate with SQL (staging + mart). |
| **ELT** | Extract → Load → Transform (load raw first, transform in the warehouse). |
| **Mart** | Final table shaped for dashboards and reports. |
| **Looker Studio** | Free Google dashboard tool (formerly Data Studio). |
| **ADC** | Application Default Credentials — how your Mac authenticates to GCP. |
| **Partition** | BigQuery splits a table by date so queries scan less data (cost control). |

---

## Success criteria — you're done when…

- [ ] Terraform created `homelab.raw_film_permits`
- [ ] You explored the API manually (Phase 1)
- [ ] Airflow DAG `nyc_film_permits` runs green for 2024 data
- [ ] Mart query shows Manhattan/Brooklyn TV dominance
- [ ] Looker Studio dashboard connects and tells a coherent story
- [ ] You can explain each layer (raw / stg / mart) to someone else

At that point you've done a real data pipeline. Everything after Phase 6 is depth, not breadth.

---

## Related docs

- **`pipelines/README.md`** — condensed Airflow setup commands
- **`docs/observability-warehouse.md`** — future: billing + CI metrics in same dataset
- **`infra/README.md`** — Terraform workflow
- **`docs/ci.md`** — GitHub Actions (for when you CI-ify Terraform)
