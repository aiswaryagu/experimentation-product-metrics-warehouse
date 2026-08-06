{{ config(materialized='view') }}

with events as (
    select * from {{ ref('stg_events') }}
),

with_prev as (
    select
        *,
        -- lag(): looks at each user's PREVIOUS event timestamp, to measure the gap
        lag(event_timestamp) over (
            partition by user_id order by event_timestamp
        ) as prev_event_timestamp
    from events
),

flagged as (
    select
        *,
        case
            when prev_event_timestamp is null then 1
            when date_diff('minute', prev_event_timestamp, event_timestamp) > 30 then 1
            else 0
        end as is_new_session
    from with_prev
),

sessionized as (
    select
        *,
        -- running total: increments every time is_new_session=1, so all events
		-- between one flag and the next share the same session number
        sum(is_new_session) over (
            partition by user_id order by event_timestamp
            rows between unbounded preceding and current row
        ) as session_seq
    from flagged
)

select
    event_id,
    user_id,
    event_name,
    event_timestamp,
    user_id || '_s' || cast(session_seq as varchar) as session_id
from sessionized