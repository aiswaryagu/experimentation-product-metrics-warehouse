with source as (
    select * from {{ source('raw', 'transactions') }}
)

-- negative amounts are NOT filtered here on purpose - a test catches
-- them instead, since silently deleting suspicious financial data
-- isn't something a pipeline should do quietly
select
    transaction_id,
    user_id,
    cast(transaction_timestamp as timestamp) as transaction_timestamp,
    cast(amount as decimal(10,2))            as amount,
    lower(trim(status))                      as status
from source
where transaction_id is not null