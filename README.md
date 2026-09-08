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
| Automated actors | 3 bot + 4 CI-vendor (patterns overlap); 4 of 20 deduped events excluded from `human_events` |
| Invalid repo slugs | 1 (5%) |
| Date span | 2024-01-01 → 2024-01-03 |

Designed to scale to **3–6 months** of `githubarchive.day.*` partitions. The
layer boundaries, tests and marts carry over unchanged; the staging model bodies
are rewritten against the BigQuery schema (see below).

## How to run (local, no cloud)

```powershell
cd path\to\dbt-github-insights
py -3 -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt

$env:DBT_PROFILES_DIR = (Get-Location).Path
copy profiles.yml.example profiles.yml   # if missing
mkdir data                               # DuckDB will not create the parent dir

dbt deps
dbt build          # seed + run + test in dependency order
dbt docs generate
dbt docs serve
```

Expected result on a clean checkout:

```
Finished running 1 seed, 6 table models, 48 data tests, 3 view models
Completed successfully
Done. PASS=58 WARN=0 ERROR=0 SKIP=0 NO-OP=0 REUSED=0 TOTAL=58
```

## Test strategy

Two classes of assertion, applied deliberately — strict where the data has no
excuse, probabilistic where a real event stream legitimately has noise.

**Strict** — a violation is a bug:

- `not_null` + numeric regex on `event_id` (all three staging models)
- `not_null` + `2020-01-01 → 2030-12-31` range on `occurred_at`
- `unique` on `event_id` in `int_events_deduped` — see below
- `unique` on `surrogate_key` in `int_events_with_keys`
- `accepted_values` on `event_type`, and on `watch_action` (GitHub only ever
  emits `started` for WatchEvent)
- Grain assertions on both marts

**Probabilistic** — a violation below threshold is expected noise:

| Test | Column | Threshold |
|------|--------|-----------|
| `mostly_not_null` | `stg_*_events.actor_login` | ≥ 98% |
| `mostly_between(1, 5000)` | `stg_push_events.push_commit_count` | ≥ 99.5% |
| `mostly_not_null` | `int_actor_login_cleaned.actor_login_clean` | ≥ 98% |

These are custom generic tests in `macros/` (see design decisions below), so
they are applied in YAML like any other test rather than copy-pasted as
singular SQL per column.

The thresholds encode **production intent** for real `githubarchive.day.*`
partitions, where deleted accounts leave `actor_login` null and force-pushes
produce genuine `push_commit_count` outliers. The local seed is clean, so these
currently pass at 100% — they are guardrails for the cloud swap, not
demonstrations of tolerated local failures.

**Volume:** table row count bounds on every staging model (relaxed for the local
seed; raise `stg_push_events` min to ~10,000 for BigQuery partitions).

### Why `unique` on `event_id` is not in staging

The seed deliberately contains event `1001` twice, one second apart — the
midnight boundary duplicate that adjacent `githubarchive.day.*` partitions
really do produce. Staging preserves the raw stream as-is, so `event_id` is
**not** unique there. `int_events_deduped` is the first model where it is, so
that is where the assertion lives. A `unique` test in staging would have been
asserting that the problem this pipeline exists to solve does not occur.

## Key design decisions

| Decision | Why |
|----------|-----|
| **DuckDB + seed first** | Full DAG and tests without GCP billing, keys, or network during development. |
| **Custom `mostly_*` generic tests** | `dbt_expectations` has no `mostly:` argument — it was never ported from Great Expectations, so `mostly:` fails with `takes no keyword argument 'mostly'` on any version. Rather than write one singular test per column, `macros/test_mostly_not_null.sql` and `macros/test_mostly_between.sql` recover the ergonomics as reusable generic tests. Both use portable SQL (no `FILTER` clause) so they run unchanged on DuckDB and BigQuery. |
| **Uniqueness asserted after dedupe** | Raw GitHub Archive partitions contain midnight boundary duplicates by design, so `unique` on `event_id` belongs on `int_events_deduped`, not staging. |
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
  marts/         mart_*.sql + _marts.yml
macros/          mostly_not_null + mostly_between generic tests
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

Honest scope: this is not a one-line target switch. The **shape** of the project
carries over — layer boundaries, materializations, test suite, mart logic — but
the three staging model bodies are rewritten, because the archive schema is
nested (`actor.login`) where the seed is flat, and the JSON and cast functions
differ.

What changes:

1. Follow `profiles.yml.bigquery.example` and `pip install dbt-bigquery`
2. Rewrite the three `stg_*_events.sql` bodies using `docs/bigquery_staging_snippets.md`
   (`actor.login` vs flat, `JSON_VALUE` vs `json_extract_string`, `INT64` vs `bigint`)
3. Rewrite the `regexp_matches` calls in `int_repo_names_normalized` and
   `int_actor_login_cleaned` as `REGEXP_CONTAINS` (snippets provided)
4. Add the `partition_by` config to `mart_daily_repo_activity`
5. Raise the `stg_push_events` row count floor to ~10,000
6. Run the exploration queries in `docs/exploration.md` and update the profile table
7. Optional: add `models/intermediate/py_actor_login_cleaned.py` per original Phase 5 spec

What does **not** change: `int_events_deduped` (uses `QUALIFY`), both marts
(portable `sum(case ...)` rather than `FILTER`), and the whole test suite
including the `mostly_*` generic tests — all written in SQL both engines accept.

## License

Portfolio project. GitHub Archive data subject to [GitHub Terms of Service](https://docs.github.com/en/site-policy/github-terms/github-terms-of-service).
