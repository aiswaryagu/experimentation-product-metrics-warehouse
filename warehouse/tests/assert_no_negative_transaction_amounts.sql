-- Fails (returns rows) if any transaction has a negative amount.
select transaction_id, amount
from {{ ref('stg_transactions') }}
where amount < 0