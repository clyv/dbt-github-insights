select
    id as event_id,
    cast(created_at as timestamp) as occurred_at,
    'PushEvent' as event_type,
    actor_login,
    cast(actor_id as varchar) as actor_id,
    repo_name,
    cast(repo_id as varchar) as repo_id,
    json_extract_string(payload, '$.ref') as git_ref,
    json_extract_string(payload, '$.size') as push_size_raw,
    cast(json_extract_string(payload, '$.size') as bigint) as push_commit_count,
    cast(null as varchar) as pr_action,
    cast(null as varchar) as watch_action,
    current_timestamp as _loaded_at
from {{ ref('raw_github_events') }}
where type = 'PushEvent'
    and created_at is not null
