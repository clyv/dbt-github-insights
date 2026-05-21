select
    {{ dbt_utils.generate_surrogate_key(['event_id', 'occurred_at']) }} as surrogate_key,
    *
from {{ ref('int_repo_names_normalized') }}
