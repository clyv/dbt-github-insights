# Phase completion tracker

| Phase | Goal | Status | Notes |
|-------|------|--------|-------|
| **0** | Accounts & tooling | **Blocked on GCP signup** | GitHub repo ✅. Python venv + fully pinned `requirements.txt` ✅. Everything on the cloud path that does not need an account is done: models are dual-target, `profiles.yml.bigquery.example` includes the Dataproc config the Python model needs, and `scripts/validate_bigquery_sql.py` parses every BigQuery branch. **Remaining work is account creation and billing, which has to be done by hand.** See "Finishing Phase 0" below. |
| **1** | Data exploration | **Done (local)** | `docs/exploration.md` has the seed profile + BigQuery query templates. Real partition stats land after the first cloud run. |
| **2** | dbt project init | **Done** | Layout: `models/{staging,intermediate,marts}`, `tests/`, `macros/`, `scripts/`, `dbt_project.yml`, `packages.yml`, layer materializations configured. |
| **3** | Staging layer | **Done** | `stg_push_events`, `stg_pr_events`, `stg_watch_events`. Dual-target: each branches on `target.type`, reading the seed locally and `githubarchive.day.*` on BigQuery. No hand-editing needed to switch. |
| **4** | Intermediate layer | **Done** | `int_events_deduped` (QUALIFY — portable across both engines), `int_repo_names_normalized` (dual-target), `int_events_with_keys` via `dbt_utils.generate_surrogate_key`. |
| **5** | Python model | **Done** | `int_actor_login_cleaned.py` is a real dbt Python model, executed in-process by dbt-duckdb and green in `dbt build`. Bot/CI classification is a maintained vendor list rather than a buried regex literal. The Dataproc/PySpark branch is written inline but unexecuted — see Phase 0. |
| **6** | dbt-expectations tests | **Done** | Strict + volume tests across all three staging models, the intermediate layer and both marts; `mostly` thresholds via custom generic tests in `macros/` (`dbt_expectations` has no `mostly:` argument). 48 data tests. |
| **7** | Mart layer | **Done** | `mart_daily_repo_activity`, `mart_contributor_summary`. Portable `sum(case ...)` aggregation; BigQuery `partition_by` applied conditionally on target. |
| **8** | Documentation & lineage | **Done** | Model descriptions + `meta` blocks throughout. Lineage is a Mermaid DAG rendered inline in the README, generated from `target/manifest.json` — it renders on GitHub without a committed screenshot and cannot go stale silently. `dbt docs serve` gives the interactive version. |
| **9** | README & portfolio | **Done** | README carries the DAG, the data profile, the test strategy and the honest BigQuery scope. |

## What runs today

```
dbt build     -> PASS=58 WARN=0 ERROR=0 SKIP=0 TOTAL=58
                 1 seed, 9 models (8 SQL + 1 Python), 48 data tests
```

## Finishing Phase 0

These steps need a human — they involve account creation, billing details and
credential files, none of which belong in a repo or in an agent's hands.

1. Create a GCP project and enable the BigQuery API
2. Create a service account, grant BigQuery Job User + Data Viewer, download the JSON key
3. Set `GCP_PROJECT_ID` and `GCP_SERVICE_ACCOUNT_KEY_PATH` in your environment
   (`.env.example` lists them; the key file itself is gitignored)
4. `pip install dbt-bigquery`
5. Merge the `bigquery` target from `profiles.yml.bigquery.example` into `profiles.yml`

Then the switch is one command — no model edits:

```powershell
dbt build --target bigquery --vars '{partition_date: "20240101"}'
```

### Expected friction on that first run

- **Cost.** `githubarchive.day.*` bills per byte scanned. Start pinned to a
  single day partition via `--vars`, check the bytes billed, then widen.
- **Row count floor.** `stg_push_events` has a row count test tuned for the
  21-row seed. Raise the minimum to ~10,000 for real partitions.
- **The Python model.** It needs Dataproc Serverless, not just BigQuery: a
  subnet with Private Google Access and `roles/dataproc.worker` on the service
  account. If you would rather not provision that, the SQL equivalent is in
  `docs/bigquery_staging_snippets.md`.
- **Unexecuted SQL.** Every BigQuery branch parses as valid BigQuery
  (`python scripts/validate_bigquery_sql.py`), but parsing is not running.
  Column names in `githubarchive.day.*` are verified against documentation,
  not against the table.
