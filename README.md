# dbt-github-insights

A dbt project that turns **GitHub Archive** event data into clean, tested analytics tables: daily repo activity and contributor summaries. Built as a portfolio piece showing layered SQL modeling, data quality gates, and a path from local dev to BigQuery at scale.

## Why it matters

The public GitHub Archive is **multi-terabyte**; most tutorials never touch real scale. This repo shows how to **scope sensibly** (days/months, not the full history), model event types separately in staging, dedupe midnight boundary duplicates, classify bot actors, and enforce **probabilistic** quality tests (`mostly`-style thresholds). It runs **locally on DuckDB** today and documents the exact switch to **BigQuery + optional Python models** when you enable cloud.

## Architecture

```
seeds/raw_github_events.csv          ← local dev (BigQuery githubarchive.day.* when cloud on)
        │
        ▼
  stg_push_events / stg_pr_events / stg_watch_events   (views)
        │
        ▼
  int_events_deduped → int_repo_names_normalized → int_events_with_keys   (tables)
        │
        ▼
  int_actor_login_cleaned   (table — SQL locally; Python optional on BigQuery)
        │
        ├──► mart_daily_repo_activity
        └──► mart_contributor_summary
```

> **Lineage screenshot:** After `dbt docs generate`, run `dbt docs serve` and capture the DAG for your portfolio README.

## Data profile (local seed)

From [docs/exploration.md](docs/exploration.md):

| Metric | Value |
|--------|-------|
| Raw rows | 21 (20 unique events after dedup) |
| Event mix | 76% Push, 10% PR, 14% Watch |
| Bot-like actors | 3 (14% of all events) |
| Invalid repo slugs | 1 (5%) |
| Date span | 2024-01-01 → 2024-01-03 |

Designed to scale to **3–6 months** of `githubarchive.day.*` partitions without redesign.

## How to run (local, no cloud)

```powershell
cd C:\Users\gejuj\dbt-github-insights
py -3.11 -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt

$env:DBT_PROFILES_DIR = (Get-Location).Path
copy profiles.yml.example profiles.yml   # if missing

dbt deps
dbt seed
dbt run
dbt test
dbt docs generate
dbt docs serve
```

## Test strategy

- **Strict:** `unique`, `not_null`, regex on `event_id`, date ranges  
- **Probabilistic:** singular tests `assert_actor_login_mostly_not_null` (≥98%) and `assert_push_commit_count_mostly_in_range` (≥99.5%) — same production intent as `mostly:` in dbt-expectations  
- **Volume:** table row count bounds on `stg_push_events` (relaxed for local seed; tighten for BigQuery)

Run `dbt test` and save all-green output for your portfolio.

## Key design decisions

| Decision | Why |
|----------|-----|
| **DuckDB + seed first** | Full DAG and tests without GCP billing, keys, or network during development. |
| **`mostly` via singular tests** | Current `dbt_expectations` + dbt 1.11 macro API rejects inline `mostly:`; singular SQL tests preserve the probabilistic DQ story. |
| **SQL actor cleaning locally** | Same regex semantics as the planned Python model; avoids BigQuery Python runtime on Windows. Restore `py_actor_login_cleaned.py` on cloud for the SQL+Python hybrid narrative. |
| **Intermediate as tables, staging as views** | Cheap fresh staging; materialize heavier transforms once. |
| **One staging model per event type** | Clear lineage and simpler downstream joins. |
| **Repo name `dbt-github-insights`** | Public portfolio repo (plan suggested `dbt-github-archive`; same purpose). |

## Project layout

```
models/
  sources.yml
  staging/       stg_*_events.sql + .yml
  intermediate/  int_* + int_actor_login_cleaned.sql
  marts/         mart_*.sql
tests/           singular mostly-* tests
seeds/           raw_github_events.csv
docs/            exploration.md, PHASE_STATUS.md, bigquery_staging_snippets.md
```

## Phase checklist

See [docs/PHASE_STATUS.md](docs/PHASE_STATUS.md) for per-phase completion.

- [x] Phases 2–4, 6–7, 9 (local)
- [x] Phase 1 profile (local seed)
- [ ] Phase 0 GCP (skipped — optional)
- [ ] Phase 5 Python model on BigQuery (documented, not required locally)
- [ ] Phase 8 lineage screenshot in README

## Enabling BigQuery later

1. Follow `profiles.yml.bigquery.example`  
2. Use SQL in `docs/bigquery_staging_snippets.md`  
3. Run exploration queries in `docs/exploration.md` and update the profile table  
4. Optional: add `models/intermediate/py_actor_login_cleaned.py` per original Phase 5 spec  

## License

Portfolio project. GitHub Archive data subject to [GitHub Terms of Service](https://docs.github.com/en/site-policy/github-terms/github-terms-of-service).
