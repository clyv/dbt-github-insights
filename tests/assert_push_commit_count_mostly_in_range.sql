-- Singular test: at least 99.5% of push_commit_count values in range [1, 5000].

with stats as (
    select
        count(*) filter (where push_commit_count is not null) as total_rows,
        count(*) filter (
            where push_commit_count between 1 and 5000
        ) as valid_rows
    from {{ ref('stg_push_events') }}
)

select *
from stats
where valid_rows * 1.0 / nullif(total_rows, 0) < 0.995
