with source as (
    select * from {{ source('raw', 'users') }}
)

select
    user_id,
    cast(signup_date as date)  as signup_date,
    upper(country)             as country,
    lower(plan_type)           as plan_type,
    lower(trim(email))         as email
from source
where user_id is not null