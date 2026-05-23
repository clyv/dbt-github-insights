select
    cast(occurred_at as date) as event_date,
    repo_owner,
    repo_slug,
    count(*) as total_events,
    count(*) filter (where coalesce(is_bot_actor, false) = false) as human_events,
    sum(push_commit_count) as total_commits
from {{ ref('int_actor_login_cleaned') }}
where is_valid_slug = true
    and event_type = 'PushEvent'
group by 1, 2, 3
