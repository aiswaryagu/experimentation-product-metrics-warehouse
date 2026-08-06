-- Cohort-level LTV rollup, built on top of fct_ltv rather than
-- recomputing the join and aggregation logic from scratch.

{{ config(materialized='table') }}

with user_ltv as (
    select * from {{ ref('fct_ltv') }}
)

select
    cohort_week,
    count(distinct user_id)      as cohort_size,
    round(avg(ltv), 2)           as avg_ltv_per_user,
    round(sum(ltv), 2)           as total_cohort_ltv
from user_ltv
group by cohort_week
order by cohort_week