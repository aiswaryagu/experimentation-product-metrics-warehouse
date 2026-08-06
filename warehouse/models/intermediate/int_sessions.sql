-- Derives session boundaries from raw event timestamps. stg_events has one
-- row per action with a timestamp, but nothing saying which "visit" it
-- belongs to - session boundaries are derived using a 30-minute gap rule.

{{ config(materialized='view') }}

with events as (
    select * from {{ ref('stg_events') }}
    -- ref() (vs source()) points at a model dbt itself built - this is how
    -- dbt knows int_sessions depends on stg_events and builds in the right order.
),

with_prev as (
    select
        *,
        -- lag() looks at the PREVIOUS row's value within each partition.
        -- Returns each user's previous event timestamp.
        -- The user's very first event has no previous one -> null.
        lag(event_timestamp) over (
            partition by user_id order by event_timestamp
        ) as prev_event_timestamp
    from events
),

flagged as (
    select
        *,
        case
            when prev_event_timestamp is null then 1   -- first event ever for this user
            when date_diff('minute', prev_event_timestamp, event_timestamp) > 30 then 1  -- gap > 30 min = new session
            else 0
        end as is_new_session
    from with_prev
),

sessionized as (
    select
        *,
        -- running total: ticks up by 1 every time is_new_session = 1.
        -- All events between one "new session" flag and the next share the
        -- same running total - that running total IS the session number.
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
    -- builds a readable session ID like u_00001_s1, u_00001_s2
    user_id || '_s' || cast(session_seq as varchar) as session_id
from sessionized