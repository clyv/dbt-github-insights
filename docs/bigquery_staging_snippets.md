# BigQuery staging snippets (Phase 3 — cloud target)

Use these in staging models when `target.name == 'bigquery'`. Current repo uses DuckDB + flat seed columns for local dev.

## stg_push_events (BigQuery)

```sql
SELECT
  id AS event_id,
  CAST(created_at AS TIMESTAMP) AS occurred_at,
  'PushEvent' AS event_type,
  actor.login AS actor_login,
  actor.id AS actor_id,
  repo.name AS repo_name,
  repo.id AS repo_id,
  JSON_VALUE(payload, '$.ref') AS git_ref,
  JSON_VALUE(payload, '$.size') AS push_size_raw,
  CAST(JSON_VALUE(payload, '$.size') AS INT64) AS push_commit_count,
  CAST(NULL AS STRING) AS pr_action,
  CAST(NULL AS STRING) AS watch_action,
  CURRENT_TIMESTAMP() AS _loaded_at
FROM {{ source('githubarchive', 'events') }}
WHERE type = 'PushEvent'
  AND created_at IS NOT NULL
```

## sources.yml (BigQuery)

```yaml
sources:
  - name: githubarchive
    database: githubarchive
    schema: day
    tables:
      - name: events
        identifier: "{{ var('partition_date', '20240101') }}"
```

## int_repo_names_normalized (BigQuery)

```sql
SPLIT(LOWER(TRIM(repo_name)), '/')[SAFE_OFFSET(0)] AS repo_owner,
SPLIT(LOWER(TRIM(repo_name)), '/')[SAFE_OFFSET(1)] AS repo_slug,
REGEXP_CONTAINS(repo_name, r'^[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+$') AS is_valid_slug
```

## mart_daily_repo_activity partition config (BigQuery)

```sql
{{ config(
    partition_by={
      "field": "event_date",
      "data_type": "date",
    }
) }}
```

Use `COUNTIF(is_bot_actor = FALSE)` instead of DuckDB `count(*) filter (where ...)`.
