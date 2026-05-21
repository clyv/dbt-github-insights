select
    id as event_id,
    cast(created_at as timestamp) as occurred_at,
    'WatchEvent' as event_type,
    actor.login as actor_login,
    actor.id as actor_id,
    repo.name as repo_name,
    repo.id as repo_id,
    cast(null as string) as git_ref,
    cast(null as string) as push_size_raw,
    cast(null as int64) as push_commit_count,
    cast(null as string) as pr_action,
    json_value(payload, '$.action') as watch_action,
    current_timestamp() as _loaded_at
from {{ source('githubarchive', 'events') }}
where type = 'WatchEvent'
    and created_at is not null
