-- Regression check: confirms the treatment variant's completion rate stays
-- above control's. This dataset has a known, designed uplift baked into the
-- experiment simulation, so this test guards against a future refactor of
-- upstream logic silently breaking that relationship - it is not a general
-- claim that treatments always outperform control.
with pivoted as (
    select
        max(case when variant = 'treatment' then session_completion_rate_pct end) as treatment_rate,
        max(case when variant = 'control'   then session_completion_rate_pct end) as control_rate
    from {{ ref('fct_experiment_results') }}
)

select *
from pivoted
where treatment_rate <= control_rate