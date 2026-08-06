-- Per-user lifetime value: sums COMPLETED transaction amounts per user.
-- Refunded/failed transactions are excluded - LTV should reflect
-- realised revenue, not attempted revenue.

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
        -- sum() on zero rows returns null, not 0. coalesce swaps any
        -- null for 0, so a user with no purchases shows 0 LTV instead
        -- of a missing value.
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

-- LEFT JOIN, joining FROM users_with_cohort (not user_ltv), is the key
-- decision here: it keeps every user, even ones with zero completed
-- transactions. A user with $0 LTV is a real, meaningful fact - joining
-- the other way would silently drop those users from the mart.
select
    u.user_id,
    u.cohort_week,
    coalesce(l.ltv, 0) as ltv,
    coalesce(l.completed_transaction_count, 0) as completed_transaction_count
from users_with_cohort u
left join user_ltv l on u.user_id = l.user_id