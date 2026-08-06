with source as (
    select * from {{ source('raw', 'events') }}
),

deduped as (
    select
        event_id,
        user_id,
        lower(trim(event_name))            as event_name,
        cast(event_timestamp as timestamp) as event_timestamp,
        -- window function: labels duplicate (user_id, event_name, event_timestamp)
		-- rows 1, 2, 3... so we can keep only the first and drop the rest
        row_number() over (
            partition by user_id, event_name, event_timestamp
            order by event_id
        ) as rn
    from source
    where user_id is not null
      and event_name is not null
)

select
    event_id,
    user_id,
    event_name,
    event_timestamp
from deduped
where rn = 1