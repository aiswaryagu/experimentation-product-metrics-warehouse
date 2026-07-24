{{ config(materialized='table') }}

with users as (
    select
        user_id,
        date_trunc('week', signup_date) as cohort_week
    from {{ ref('stg_users') }}
),

activity as (
    select
        user_id,
        date_trunc('week', event_timestamp) as activity_week
    from {{ ref('int_sessions') }}
    group by user_id, date_trunc('week', event_timestamp)
),

joined as (
    select
        u.user_id,
        u.cohort_week,
        a.activity_week,
        date_diff('week', u.cohort_week, a.activity_week) as weeks_since_signup
    from users u
    inner join activity a on u.user_id = a.user_id
    where a.activity_week >= u.cohort_week
),

cohort_sizes as (
    select cohort_week, count(distinct user_id) as cohort_size
    from users
    group by cohort_week
),

retention as (
    select
        cohort_week,
        weeks_since_signup,
        count(distinct user_id) as active_users
    from joined
    group by cohort_week, weeks_since_signup
)

select
    r.cohort_week,
    r.weeks_since_signup,
    r.active_users,
    c.cohort_size,
    # nullif guards against divide-by-zero if a cohort somehow had 0 users
    round(100.0 * r.active_users / nullif(c.cohort_size, 0), 1) as retention_pct
from retention r
inner join cohort_sizes c on r.cohort_week = c.cohort_week
order by r.cohort_week, r.weeks_since_signup