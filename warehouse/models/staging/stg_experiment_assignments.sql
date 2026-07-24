with source as (
    select * from {{ source('raw', 'experiment_assignments') }}
)

select
    user_id,
    experiment_name,
    lower(trim(variant))           as variant,
    cast(assigned_at as timestamp) as assigned_at
from source
where user_id is not null
  and variant in ('control', 'treatment')