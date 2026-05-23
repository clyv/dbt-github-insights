select
    id as event_id,
    cast(created_at as timestamp) as occurred_at,
    'PullRequestEvent' as event_type,
    actor_login,
    cast(actor_id as varchar) as actor_id,
    repo_name,
    cast(repo_id as varchar) as repo_id,
    cast(null as varchar) as git_ref,
    cast(null as varchar) as push_size_raw,
    cast(null as bigint) as push_commit_count,
    json_extract_string(payload, '$.action') as pr_action,
    cast(null as varchar) as watch_action,
    current_timestamp as _loaded_at
from {{ ref('raw_github_events') }}
where type = 'PullRequestEvent'
    and created_at is not null
