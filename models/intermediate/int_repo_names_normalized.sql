-- Splits repo slugs into owner/name and flags well-formed org/repo values.
--
-- Dual-target: DuckDB has split_part + regexp_matches; BigQuery has
-- SPLIT(...)[SAFE_OFFSET(n)] + REGEXP_CONTAINS.

select
    *,
    lower(trim(repo_name)) as repo_name_clean,

{% if target.type == 'bigquery' %}
    split(lower(trim(repo_name)), '/')[safe_offset(0)] as repo_owner,
    split(lower(trim(repo_name)), '/')[safe_offset(1)] as repo_slug,
    regexp_contains(
        repo_name,
        r'^[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+$'
    ) as is_valid_slug
{% else %}
    split_part(lower(trim(repo_name)), '/', 1) as repo_owner,
    split_part(lower(trim(repo_name)), '/', 2) as repo_slug,
    regexp_matches(
        repo_name,
        '^[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+$'
    ) as is_valid_slug
{% endif %}

from {{ ref('int_events_deduped') }}
