# BigQuery staging snippets (Phase 3 — cloud target)

**These are now implemented in the models themselves**, inside
`{% if target.type == 'bigquery' %}` branches — they no longer need to be
copied anywhere. This file is kept as the reference for *why* each translation
is what it is, and as the place to work out new ones.

Validate any change here against the BigQuery dialect without a GCP project:

    python scripts/validate_bigquery_sql.py

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

No change needed to the aggregation itself — `mart_daily_repo_activity` uses
portable `sum(case when ... then 1 else 0 end)` rather than DuckDB's
`count(*) filter (where ...)`, which BigQuery does not support.

## int_events_deduped (BigQuery)

No change needed. The dedupe uses `QUALIFY`, which both DuckDB and BigQuery
support, rather than a `row_number()` CTE followed by a star-exclusion
(`EXCLUDE` on DuckDB, `EXCEPT` on BigQuery — the two dialects disagree).

## int_actor_login_cleaned (BigQuery)

```sql
REGEXP_CONTAINS(actor_login, r'(?i)(\[bot\]$|-bot$|^bot-)') AS is_bot_actor,
REGEXP_CONTAINS(actor_login, r'(?i)^(travis|circleci|dependabot|renovate|snyk)') AS is_ci_actor,
LOWER(TRIM(actor_login)) AS actor_login_clean
```

BigQuery has no case-insensitivity flag argument, so the `(?i)` inline flag
replaces DuckDB's third `regexp_matches(..., 'i')` parameter.
