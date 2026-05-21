# GitHub Archive — data exploration (Phase 1)

Run these in the **BigQuery console** against public data before changing models.
Replace dates with your chosen scope (MVP: one day `20240101`; portfolio: 3–6 months).

## Sanity check — event types

```sql
SELECT type, COUNT(*) AS cnt
FROM `githubarchive.day.20240101`
GROUP BY type
ORDER BY cnt DESC
LIMIT 20;
```

**Record results:** PushEvent ~___%, PullRequestEvent ~___%, WatchEvent ~___%.

## Bot / null actor logins

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

**Fill in after run:** null % = ___ , bot-like % = ___

## Repo name cardinality & malformed slugs

```sql
SELECT
  COUNT(DISTINCT repo.name) AS distinct_repo_names,
  COUNTIF(repo.name IS NULL) AS null_repo_names,
  COUNTIF(NOT REGEXP_CONTAINS(repo.name, r'^[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+$')) AS invalid_slug_rows
FROM `githubarchive.day.20240101`;
```

## Time range & volume (single day vs month)

```sql
-- Single day
SELECT
  MIN(created_at) AS min_ts,
  MAX(created_at) AS max_ts,
  COUNT(*) AS row_count
FROM `githubarchive.day.20240101`;

-- Example month scope (adjust table wildcard / union as needed)
-- SELECT COUNT(*) FROM `githubarchive.day.202401*`;
```

**Scope decision:** Modelling ___ months of ___ (document bytes processed in README).

## Partition size note

Query cost for public `githubarchive` under 1 TB/month free tier is usually **$0** for exploration-sized scans.
Always check **bytes processed** in the BQ job details before scaling to full-year unions.
