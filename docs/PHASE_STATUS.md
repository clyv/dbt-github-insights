# Phase completion tracker

| Phase | Goal | Status | Notes |
|-------|------|--------|-------|
| **0** | Accounts & tooling | **Partial** | GitHub repo ✅ (`dbt-github-insights`). Python venv + pinned `requirements.txt` ✅. **GCP skipped** by choice — use DuckDB locally; `profiles.yml.bigquery.example` ready when needed. |
| **1** | Data exploration | **Done (local)** | `docs/exploration.md` has seed profile + BigQuery query templates. Fill BQ columns when cloud is enabled. |
| **2** | dbt project init | **Done** | Layout: `models/{staging,intermediate,marts}`, `tests/`, `macros/`, `dbt_project.yml`, `packages.yml`, layer materializations configured. |
| **3** | Staging layer | **Done** | `stg_push_events`, `stg_pr_events`, `stg_watch_events` + `sources.yml`. Reads local seed; BQ snippets in `docs/bigquery_staging_snippets.md`. |
| **4** | Intermediate layer | **Done** | `int_events_deduped`, `int_repo_names_normalized`, `int_events_with_keys` with `dbt_utils.generate_surrogate_key`. |
| **5** | Python model | **Partial** | Implemented as **`int_actor_login_cleaned.sql`** for DuckDB (no cloud Python runtime). Original `py_actor_login_cleaned.py` pattern documented in README for BigQuery resume. |
| **6** | dbt-expectations tests | **Done** | Strict + volume tests across all three staging models, intermediate and marts; `mostly` thresholds via custom generic tests in `macros/` (`dbt_expectations` has no `mostly:` argument). |
| **7** | Mart layer | **Done** | `mart_daily_repo_activity`, `mart_contributor_summary`. DuckDB-compatible SQL; BQ partition config documented. |
| **8** | Documentation & lineage | **Partial** | Model descriptions + `meta` blocks in YAML. Run `dbt docs generate && dbt docs serve` locally for lineage screenshot. |
| **9** | README & portfolio | **Done** | README structured per portfolio template below. |

## MVP interview story (Phases 0–6)

You can demo: **seed → staging → intermediate → actor cleaning → tests green** without GCP.

## To finish cloud path later

1. GCP project + service account + BigQuery API  
2. Copy `profiles.yml.bigquery.example` → add `bigquery` target  
3. `pip install dbt-bigquery` (separate venv or requirements profile)  
4. Swap staging SQL using `docs/bigquery_staging_snippets.md`  
5. Restore `py_actor_login_cleaned.py` (optional differentiation)  
6. Run Phase 1 BigQuery queries and update exploration doc with real stats  
7. Raise `expect_table_row_count` min to 10,000 for production partitions (the `mostly_*` generic tests need no change — portable SQL, no `FILTER` clause)  
