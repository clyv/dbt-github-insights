with combined as (
    select * from {{ ref('stg_push_events') }}
    union all
    select * from {{ ref('stg_pr_events') }}
    union all
    select * from {{ ref('stg_watch_events') }}
),

ranked as (
    select
        *,
        row_number() over (
            partition by event_id
            order by occurred_at
        ) as rn
    from combined
)

select * except (rn)
from ranked
where rn = 1
