-- Singular test: at least 98% of push events have a non-null actor_login.
-- Mirrors production "mostly" thresholds when dbt_expectations mostly= is unavailable.

with stats as (
    select
        count(*) as total_rows,
        count(*) filter (where actor_login is not null) as non_null_rows
    from {{ ref('stg_push_events') }}
)

select *
from stats
where non_null_rows * 1.0 / nullif(total_rows, 0) < 0.98
