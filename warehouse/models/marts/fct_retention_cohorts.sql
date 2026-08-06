-- Retention cohort mart: group users by the WEEK they signed up (a
-- "cohort"), then for each subsequent week, count how many of those same
-- users showed any activity. The declining pattern is retention.

{{ config(materialized='table') }}

with users as (
    select
        user_id,
        -- rounds a date DOWN to the start of its week - two users signing
        -- up on different days of the same week get the same cohort_week
        date_trunc('week', signup_date) as cohort_week
    from {{ ref('stg_users') }}
),

activity as (
    select
        user_id,
        date_trunc('week', event_timestamp) as activity_week
    from {{ ref('int_sessions') }}
    group by user_id, date_trunc('week', event_timestamp)
    -- group by here just gets distinct (user, week) combinations
),

joined as (
    select
        u.user_id,
        u.cohort_week,
        a.activity_week,
        -- weeks_since_signup: 0 = signup week itself, 1 = one week later, etc.
        date_diff('week', u.cohort_week, a.activity_week) as weeks_since_signup
    from users u
    inner join activity a on u.user_id = a.user_id
    where a.activity_week >= u.cohort_week
    -- safety check: guards against any activity appearing to happen
    -- before signup (shouldn't occur with clean data, but cheap to check)
),

cohort_sizes as (
    -- total users per cohort week - this is the denominator for a percentage
    select cohort_week, count(distinct user_id) as cohort_size
    from users
    group by cohort_week
),

retention as (
    select
        cohort_week,
        weeks_since_signup,
        -- count(distinct ...) matters: a user might have multiple sessions
        -- in one week, so each user is counted only once
        count(distinct user_id) as active_users
    from joined
    group by cohort_week, weeks_since_signup
)

select
    r.cohort_week,
    r.weeks_since_signup,
    r.active_users,
    c.cohort_size,
    -- nullif(c.cohort_size, 0): safety guard against divide-by-zero -
    -- converts a zero into null first, so division just gives null
    -- instead of erroring
    round(100.0 * r.active_users / nullif(c.cohort_size, 0), 1) as retention_pct
from retention r
inner join cohort_sizes c on r.cohort_week = c.cohort_week
order by r.cohort_week, r.weeks_since_signup