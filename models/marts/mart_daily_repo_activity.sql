-- Daily push activity per repo.
--
-- human_events excludes both bot accounts (dependabot[bot], *-bot) and CI
-- vendors (travis, circleci, renovate, snyk). Excluding only is_bot_actor
-- would count travis-ci pushes as human activity.
--
-- Portable aggregation (case/sum rather than count(*) filter) so the same SQL
-- runs on DuckDB locally and BigQuery in the cloud target.

select
    cast(occurred_at as date) as event_date,
    repo_owner,
    repo_slug,
    count(*) as total_events,
    sum(
        case
            when coalesce(is_bot_actor, false) = false
                and coalesce(is_ci_actor, false) = false
            then 1
            else 0
        end
    ) as human_events,
    sum(push_commit_count) as total_commits
from {{ ref('int_actor_login_cleaned') }}
where is_valid_slug = true
    and event_type = 'PushEvent'
group by 1, 2, 3
