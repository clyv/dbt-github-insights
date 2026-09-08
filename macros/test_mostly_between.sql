{#
    Generic test: assert that at least `threshold` (0-1) of NON-NULL values in
    `column_name` fall within [min_value, max_value].

    Nulls are excluded from the denominator -- null coverage is asserted
    separately by `mostly_not_null` so the two failures stay distinguishable.

    Portable SQL (no FILTER clause) so the same test runs on DuckDB locally
    and BigQuery in the cloud target.
#}

{% test mostly_between(model, column_name, min_value, max_value, threshold=0.99) %}

with stats as (
    select
        sum(case when {{ column_name }} is not null then 1 else 0 end) as total_rows,
        sum(
            case
                when {{ column_name }} between {{ min_value }} and {{ max_value }} then 1
                else 0
            end
        ) as passing_rows
    from {{ model }}
)

select
    total_rows,
    passing_rows,
    passing_rows * 1.0 / nullif(total_rows, 0) as pass_rate,
    {{ threshold }} as threshold
from stats
where passing_rows * 1.0 / nullif(total_rows, 0) < {{ threshold }}

{% endtest %}
