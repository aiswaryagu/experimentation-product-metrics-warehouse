-- Funnel conversion mart: for each of the 5 funnel steps, how many
-- SESSIONS reached that step at least once?

{{ config(materialized='table') }}
-- 'table' (not the default 'view') - marts get queried repeatedly by
-- dashboards/analysts, so the result is materialised to disk once
-- rather than recomputing the whole thing on every read.

with sessions as (
    select * from {{ ref('int_sessions') }}
),

-- did each session reach each funnel step at least once?
session_steps as (
    select
        session_id,
        -- turn a condition into 1/0, then take max() per group = "did this
        -- session have AT LEAST ONE event of this type" (max of 0s/1s is 1
        -- if even a single row was a 1)
        max(case when event_name = 'page_view'         then 1 else 0 end) as reached_page_view,
        max(case when event_name = 'signup'             then 1 else 0 end) as reached_signup,
        max(case when event_name = 'add_to_cart'        then 1 else 0 end) as reached_add_to_cart,
        max(case when event_name = 'checkout_start'     then 1 else 0 end) as reached_checkout_start,
        max(case when event_name = 'checkout_complete'  then 1 else 0 end) as reached_checkout_complete
    from sessions
    group by session_id
),

totals as (
    -- sums the per-session 1/0 flags across ALL sessions = total count
    -- of sessions that reached each step
    select
        sum(reached_page_view)         as page_view_sessions,
        sum(reached_signup)            as signup_sessions,
        sum(reached_add_to_cart)       as add_to_cart_sessions,
        sum(reached_checkout_start)    as checkout_start_sessions,
        sum(reached_checkout_complete) as checkout_complete_sessions
    from session_steps
)

-- stacks 5 separate one-row results into a single 5-row table, one row per
-- funnel step. NOTE: column names in a union all come ONLY from the first
-- select - every select after that just needs to match column ORDER.
select
    'page_view' as funnel_step,
    1            as step_order,
    page_view_sessions as sessions_reached
from totals
union all
select 'signup',            2, signup_sessions            from totals
union all
select 'add_to_cart',       3, add_to_cart_sessions       from totals
union all
select 'checkout_start',    4, checkout_start_sessions    from totals
union all
select 'checkout_complete', 5, checkout_complete_sessions from totals
