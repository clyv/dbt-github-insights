-- Unions the three staging event types and removes midnight boundary
-- duplicates: the same event_id can land in two adjacent githubarchive.day.*
-- partitions with timestamps a second apart. Keeps the earliest occurrence.
--
-- QUALIFY (rather than a row_number CTE + `select * except/exclude (rn)`) keeps
-- this portable: DuckDB spells the star-exclusion EXCLUDE, BigQuery spells it
-- EXCEPT, and QUALIFY is valid in both.

with combined as (
    select * from {{ ref('stg_push_events') }}
    union all
    select * from {{ ref('stg_pr_events') }}
    union all
    select * from {{ ref('stg_watch_events') }}
)

select *
from combined
where event_id is not null
qualify row_number() over (
    partition by event_id
    order by occurred_at
) = 1
