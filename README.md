# dbt-github-insights

dbt pipeline modeling **GitHub Archive–style events**: staging → intermediate (dedup, slug parsing, surrogate keys, actor classification) → marts, with **dbt-expectations** tests.

**Local mode (default):** DuckDB + CSV seed — no GCP or BigQuery required.  
**Cloud mode (optional later):** swap the seed for `githubarchive.day.*` on BigQuery.

## Architecture

```
seeds/raw_github_events.csv
        │
        ▼
  stg_push_events / stg_pr_events / stg_watch_events   (views)
        │
        ▼
  int_events_deduped → int_repo_names_normalized → int_events_with_keys
        │
        ▼
  int_actor_login_cleaned   (table)
        │
        ├──► mart_daily_repo_activity
        └──► mart_contributor_summary
```

## Quick start (local, no cloud)

```powershell
cd C:\Users\gejuj\dbt-github-insights
py -3.11 -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt

$env:DBT_PROFILES_DIR = (Get-Location).Path
copy profiles.yml.example profiles.yml   # if profiles.yml missing

dbt deps
dbt seed
dbt run
dbt test
```

`profiles.yml` points at `data/github_archive.duckdb` (created on first run; gitignored).

## Key design decisions

| Decision | Rationale |
|----------|-----------|
| DuckDB + seed for local dev | Run and test the full DAG without GCP billing or keys. |
| `mostly:` on tests | Sample data includes null actors and bots; strict 100% rules fail on noise. |
| SQL actor cleaning (not Python) | Same regex semantics; fewer moving parts on Windows without cloud Python runtimes. |
| Duplicate `event_id` in seed | Exercises `int_events_deduped` window dedup. |

## Enabling BigQuery later

1. Install `dbt-bigquery` and use a BigQuery `profiles.yml` target.
2. Point staging models at `source('githubarchive', 'events')` with flattened or nested columns.
3. Restore BigQuery-specific functions (`json_value`, `safe_offset`, etc.) in staging SQL.

See `docs/exploration.md` for exploratory queries (BigQuery console).

## Portfolio checklist

- [ ] `dbt test` green locally
- [ ] `dbt docs generate` + lineage screenshot
- [ ] Fill `docs/exploration.md` when using real archive data
