-- Fails (returns rows) if a later funnel step somehow has more sessions
-- than an earlier step, which would indicate a modeling bug.
with ordered as (
    select
        funnel_step,
        step_order,
        sessions_reached,
        lag(sessions_reached) over (order by step_order) as prev_step_sessions
    from {{ ref('fct_funnel_conversion') }}
)

select *
from ordered
where prev_step_sessions is not null
  and sessions_reached > prev_step_sessions