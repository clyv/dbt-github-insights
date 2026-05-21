# dbt-github-insights

End-to-end **dbt + BigQuery** pipeline on the public [GitHub Archive](https://www.gharchive.org/) dataset: staging → intermediate (dedup, slug parsing, surrogate keys) → **Python** actor classification → partitioned marts, with **dbt-expectations** quality gates.

Designed for a **single-day MVP** (`partition_date: 20240101`) with a clear path to 3–6 months of data without scanning the full multi-TB history.

## Why this project

- **Scale story:** GitHub Archive is multi-TB; this repo models a bounded slice and documents how to extend.
- **Hybrid transforms:** SQL for bulk cleaning; Python (Pandas) where multiple semantic regex rules are clearer than chained `REGEXP_CONTAINS`.
- **Production-style tests:** `mostly:` thresholds on nullability and ranges — probabilistic DQ, not brittle 100% rules.

## Architecture

```
GitHub Archive (BigQuery public)
        │
        ▼
  stg_push_events / stg_pr_events / stg_watch_events   (views)
        │
        ▼
  int_events_deduped → int_repo_names_normalized → int_events_with_keys   (tables)
        │
        ▼
  py_actor_login_cleaned   (Python table)
        │
        ├──► mart_daily_repo_activity      (partitioned by event_date)
        └──► mart_contributor_summary
```

After `dbt docs generate`, run `dbt docs serve` for the interactive lineage graph (portfolio screenshot).

## Phase 0 — Setup (do this first)

### 1. GCP

1. Create a GCP project (e.g. `github-archive-dbt`).
2. Enable **BigQuery API**.
3. Create a service account with **BigQuery Data Editor** + **BigQuery Job User**.
4. Download JSON key → store **outside** the repo.

### 2. Verify public data (BigQuery console)

```sql
SELECT type, COUNT(*) AS cnt
FROM `githubarchive.day.20240101`
GROUP BY type
LIMIT 10;
```

Confirm PushEvent / PullRequestEvent / WatchEvent; check bytes processed (should stay in free tier for this query).

### 3. Python + dbt

```powershell
cd C:\Users\gejuj\dbt-github-insights
py -3.11 -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

Copy `profiles.yml.example` → `%USERPROFILE%\.dbt\profiles.yml` and set:

- `GCP_PROJECT_ID`
- `GCP_SERVICE_ACCOUNT_KEY_PATH` (or use `.env` + `profiles.yml` env_var pattern from the example)

### 4. Install packages & debug

```powershell
dbt deps
dbt debug
```

### 5. Run pipeline

```powershell
dbt run --select staging
dbt run --select intermediate
dbt run --select py_actor_login_cleaned
dbt run --select marts
dbt test
```

To change the day partition, set in `dbt_project.yml` or CLI:

```powershell
dbt run --vars '{"partition_date": "20240102"}'
```

## Data profile

Fill in [docs/exploration.md](docs/exploration.md) after running Phase 1 queries (null rates, bot %, slug validity, row counts). Link key stats here for README readers.

## Key design decisions

| Decision | Rationale |
|----------|-----------|
| `mostly: 0.98` on `actor_login` | Real archive data has sparse null actors; strict `not_null` fails on noise, not signal. |
| Python for bot/CI regex | Several semantic patterns + readability; unit-testable in Pandas. |
| Intermediate as **tables** | Heavier transforms run once; staging stays **views** for cheap freshness. |
| `mart_daily_repo_activity` **partitioned** | BigQuery prune on `event_date` for analyst queries. |
| Single `partition_date` var | MVP scope; extend with unions/macros for multi-month (see exploration doc). |

## Project layout

```
models/
  sources.yml
  staging/     stg_*_events.sql + tests
  intermediate/  int_* + py_actor_login_cleaned.py
  marts/       mart_*.sql
docs/exploration.md
dbt_project.yml
packages.yml
requirements.txt
profiles.yml.example
```

## Portfolio checklist

- [ ] Phase 0: GCP + `dbt debug` green
- [ ] Phase 1: `docs/exploration.md` filled with real numbers
- [ ] Phase 6: `dbt test` all green (screenshot)
- [ ] Phase 8: `dbt docs generate` + lineage screenshot
- [ ] Push to GitHub (no JSON keys, no `profiles.yml`)

## License

Public portfolio project — GitHub Archive data is subject to [GitHub's terms](https://docs.github.com/en/site-policy/github-terms/github-terms-of-service).
