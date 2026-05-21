select
    id as event_id,
    cast(created_at as timestamp) as occurred_at,
    'PushEvent' as event_type,
    actor.login as actor_login,
    actor.id as actor_id,
    repo.name as repo_name,
    repo.id as repo_id,
    json_value(payload, '$.ref') as git_ref,
    json_value(payload, '$.size') as push_size_raw,
    cast(json_value(payload, '$.size') as int64) as push_commit_count,
    cast(null as string) as pr_action,
    cast(null as string) as watch_action,
    current_timestamp() as _loaded_at
from {{ source('githubarchive', 'events') }}
where type = 'PushEvent'
    and created_at is not null
