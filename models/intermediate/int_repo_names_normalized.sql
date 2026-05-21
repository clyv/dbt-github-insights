select
    *,
    lower(trim(repo_name)) as repo_name_clean,
    split(lower(trim(repo_name)), '/')[safe_offset(0)] as repo_owner,
    split(lower(trim(repo_name)), '/')[safe_offset(1)] as repo_slug,
    regexp_contains(
        repo_name,
        r'^[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+$'
    ) as is_valid_slug
from {{ ref('int_events_deduped') }}
