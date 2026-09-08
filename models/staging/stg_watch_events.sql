-- Dual-target staging. See stg_push_events.sql for the rationale; the
-- BigQuery branch is written but not yet executed against real partitions.

{% if target.type == 'bigquery' %}

select
    id as event_id,
    cast(created_at as timestamp) as occurred_at,
    'WatchEvent' as event_type,
    actor.login as actor_login,
    cast(actor.id as string) as actor_id,
    repo.name as repo_name,
    cast(repo.id as string) as repo_id,
    cast(null as string) as git_ref,
    cast(null as string) as push_size_raw,
    cast(null as int64) as push_commit_count,
    cast(null as string) as pr_action,
    json_value(payload, '$.action') as watch_action,
    current_timestamp() as _loaded_at
from {{ source('githubarchive', 'events') }}
where type = 'WatchEvent'
    and created_at is not null

{% else %}

select
    id as event_id,
    cast(created_at as timestamp) as occurred_at,
    'WatchEvent' as event_type,
    actor_login,
    cast(actor_id as varchar) as actor_id,
    repo_name,
    cast(repo_id as varchar) as repo_id,
    cast(null as varchar) as git_ref,
    cast(null as varchar) as push_size_raw,
    cast(null as bigint) as push_commit_count,
    cast(null as varchar) as pr_action,
    json_extract_string(payload, '$.action') as watch_action,
    current_timestamp as _loaded_at
from {{ ref('raw_github_events') }}
where type = 'WatchEvent'
    and created_at is not null

{% endif %}
