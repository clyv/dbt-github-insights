select
    actor_login_clean,
    is_bot_actor,
    count(distinct repo_slug) as unique_repos_contributed,
    count(*) as total_push_events,
    min(occurred_at) as first_seen_at,
    max(occurred_at) as last_seen_at
from {{ ref('py_actor_login_cleaned') }}
where is_valid_slug = true
    and event_type = 'PushEvent'
group by 1, 2
