select
    *,
    coalesce(
        regexp_matches(actor_login, '(\[bot\]$|-bot$|^bot-)', 'i'),
        false
    ) as is_bot_actor,
    coalesce(
        regexp_matches(
            actor_login,
            '^(travis|circleci|dependabot|renovate|snyk)',
            'i'
        ),
        false
    ) as is_ci_actor,
    lower(trim(actor_login)) as actor_login_clean
from {{ ref('int_events_with_keys') }}
