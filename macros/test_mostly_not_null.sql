{#
    Generic test: assert that at least `threshold` (0-1) of rows have a
    non-null value in `column_name`.

    dbt_expectations has no `mostly:` argument -- it was never ported from
    Great Expectations -- so this recovers the same ergonomics as a reusable
    generic test rather than a one-off singular test per column.

    Portable SQL (no FILTER clause) so the same test runs on DuckDB locally
    and BigQuery in the cloud target.
#}

{% test mostly_not_null(model, column_name, threshold=0.99) %}

with stats as (
    select
        count(*) as total_rows,
        sum(case when {{ column_name }} is not null then 1 else 0 end) as passing_rows
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
