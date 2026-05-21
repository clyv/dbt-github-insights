{{
    config(
        partition_by={
            "field": "event_date",
            "data_type": "date",
        }
    )
}}

select
    date(occurred_at) as event_date,
    repo_owner,
    repo_slug,
    count(*) as total_events,
    countif(is_bot_actor = false) as human_events,
    sum(push_commit_count) as total_commits
from {{ ref('py_actor_login_cleaned') }}
where is_valid_slug = true
    and event_type = 'PushEvent'
group by 1, 2, 3
