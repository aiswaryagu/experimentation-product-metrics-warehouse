-- Experiment results mart: for each variant (control/treatment), what
-- fraction of a user's sessions reached checkout_complete? This turns
-- an earlier ad-hoc query into a permanent, tested, reproducible model.

{{ config(materialized='table') }}

with sessions as (
    select distinct user_id, session_id
    from {{ ref('int_sessions') }}
),

completions as (
    select distinct user_id, session_id
    from {{ ref('int_sessions') }}
    where event_name = 'checkout_complete'
),

per_user as (
    select
        s.user_id,
        count(distinct s.session_id)  as total_sessions,
        count(distinct c.session_id)  as completed_sessions
    from sessions s
    -- left join: same reasoning as fct_ltv - a user with zero completions
    -- should show completed_sessions = 0, not disappear from the result
    left join completions c
        on s.user_id = c.user_id
        and s.session_id = c.session_id
    group by s.user_id
),

with_variant as (
    select
        p.user_id,
        p.total_sessions,
        p.completed_sessions,
        e.variant
    from per_user p
    -- INNER join here, deliberately different from fct_ltv's left join:
    -- a user with no experiment assignment cannot be compared as
    -- control/treatment, so it is correct to drop them from this mart
    inner join {{ ref('stg_experiment_assignments') }} e
        on p.user_id = e.user_id
)

select
    variant,
    count(distinct user_id)                                          as users,
    sum(total_sessions)                                              as total_sessions,
    sum(completed_sessions)                                          as completed_sessions,
    round(100.0 * sum(completed_sessions) / sum(total_sessions), 2)  as session_completion_rate_pct
from with_variant
group by variant