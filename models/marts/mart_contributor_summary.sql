-- Contributor-level push summary. Grain: one row per cleaned actor login.
--
-- is_bot_actor and is_ci_actor are functionally dependent on
-- actor_login_clean, so grouping by all three preserves the one-row-per-
-- contributor grain (asserted by the unique test on actor_login_clean).

select
    actor_login_clean,
    is_bot_actor,
    is_ci_actor,
    count(distinct repo_slug) as unique_repos_contributed,
    count(*) as total_push_events,
    min(occurred_at) as first_seen_at,
    max(occurred_at) as last_seen_at
from {{ ref('int_actor_login_cleaned') }}
where is_valid_slug = true
    and event_type = 'PushEvent'
group by 1, 2, 3
