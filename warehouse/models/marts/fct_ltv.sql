{{ config(materialized='table') }}

with completed_transactions as (
    select
        user_id,
        amount
    from {{ ref('stg_transactions') }}
    where status = 'completed'
),

user_ltv as (
    select
        user_id,
        coalesce(sum(amount), 0) as ltv,
        count(*) as completed_transaction_count
    from completed_transactions
    group by user_id
),

users_with_cohort as (
    select
        user_id,
        date_trunc('week', signup_date) as cohort_week
    from {{ ref('stg_users') }}
)

select
    u.user_id,
    u.cohort_week,
    coalesce(l.ltv, 0) as ltv,
    coalesce(l.completed_transaction_count, 0) as completed_transaction_count
from users_with_cohort u
left join user_ltv l on u.user_id = l.user_id