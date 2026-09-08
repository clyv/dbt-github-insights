-- Dual-target staging. The archive schema is nested (actor.login) where the
-- local seed is flat, and the JSON/cast builtins differ, so the projection
-- branches on target.type rather than being hand-edited when cloud is enabled.
--
-- The BigQuery branch is written against the documented githubarchive.day.*
-- schema but has not been executed against real partitions -- no GCP project
-- is wired up yet. See README "Enabling BigQuery".

{% if target.type == 'bigquery' %}

select
    id as event_id,
    cast(created_at as timestamp) as occurred_at,
    'PushEvent' as event_type,
    actor.login as actor_login,
    cast(actor.id as string) as actor_id,
    repo.name as repo_name,
    cast(repo.id as string) as repo_id,
    json_value(payload, '$.ref') as git_ref,
    json_value(payload, '$.size') as push_size_raw,
    cast(json_value(payload, '$.size') as int64) as push_commit_count,
    cast(null as string) as pr_action,
    cast(null as string) as watch_action,
    current_timestamp() as _loaded_at
from {{ source('githubarchive', 'events') }}
where type = 'PushEvent'
    and created_at is not null

{% else %}

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

{% endif %}
