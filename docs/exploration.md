# Phase 1 — Data profile

Exploration against **local seed** (`seeds/raw_github_events.csv`) and **BigQuery** queries to run when cloud is enabled.

## Local seed profile (computed)

| Metric | Value |
|--------|-------|
| Total raw rows | 21 |
| Unique `event_id` (after dedup) | 20 |
| PushEvent | 16 (76%) |
| PullRequestEvent | 2 (10%) |
| WatchEvent | 3 (14%) |
| Null `actor_login` | 0 (0%) |
| Bot-like actors (`[bot]`, `-bot`, `^bot-`) | 3 (dependabot\[bot\], renovate-bot, snyk-bot) |
| CI-like actors (travis-ci pattern) | 1 |
| Distinct `repo_name` | 5 |
| Invalid slug (not `org/repo`) | 1 (`bad-repo-no-slash`, 5%) |
| Time range | 2024-01-01 10:00 → 2024-01-03 09:00 UTC |
| Scope decision | **3 days** of sample data locally; pipeline designed to scale to **3–6 months** on BigQuery day partitions |

Reproduce locally after `dbt seed`:

```sql
-- Run in DuckDB (data/github_archive.duckdb) or dbt compile + query
select type, count(*) as cnt from raw_github_events group by 1;
```

## BigQuery exploration (when cloud enabled)

Run in the **BigQuery console** against public data. MVP day: `20240101`; portfolio scope: 3–6 months of `githubarchive.day.YYYYMMDD` tables.

### Sanity check — event types

```sql
SELECT type, COUNT(*) AS cnt
FROM `githubarchive.day.20240101`
GROUP BY type
ORDER BY cnt DESC
LIMIT 20;
```

**Record results:** PushEvent ~___%, PullRequestEvent ~___%, WatchEvent ~___%.

### Bot / null actor logins

```sql
SELECT
  COUNT(*) AS total_rows,
  COUNTIF(actor.login IS NULL) AS null_logins,
  COUNTIF(REGEXP_CONTAINS(actor.login, r'\[bot\]|-bot|^bot-')) AS bot_like_logins,
  ROUND(100 * COUNTIF(actor.login IS NULL) / COUNT(*), 2) AS pct_null,
  ROUND(
    100 * COUNTIF(REGEXP_CONTAINS(actor.login, r'\[bot\]|-bot|^bot-')),
    COUNT(*),
    2
  ) AS pct_bot_like
FROM `githubarchive.day.20240101`;
```

### Repo name cardinality & malformed slugs

```sql
SELECT
  COUNT(DISTINCT repo.name) AS distinct_repo_names,
  COUNTIF(repo.name IS NULL) AS null_repo_names,
  COUNTIF(NOT REGEXP_CONTAINS(repo.name, r'^[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+$')) AS invalid_slug_rows
FROM `githubarchive.day.20240101`;
```

### Time range & volume

```sql
SELECT
  MIN(created_at) AS min_ts,
  MAX(created_at) AS max_ts,
  COUNT(*) AS row_count
FROM `githubarchive.day.20240101`;
```

**Scope decision for BigQuery:** Model **3 months** of 2024 (Jan–Mar) — enough for portfolio lineage without scanning multi-TB history.

### Cost note

Public `githubarchive` queries under **1 TB/month** free tier are typically **$0**. Check bytes processed in job details before scaling.
