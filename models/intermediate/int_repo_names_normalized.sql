select
    *,
    lower(trim(repo_name)) as repo_name_clean,
    split_part(lower(trim(repo_name)), '/', 1) as repo_owner,
    split_part(lower(trim(repo_name)), '/', 2) as repo_slug,
    regexp_matches(
        repo_name,
        '^[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+$'
    ) as is_valid_slug
from {{ ref('int_events_deduped') }}
