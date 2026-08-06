import streamlit as st
import duckdb
import plotly.express as px

st.set_page_config(page_title="Product Metrics Warehouse", layout="wide")

st.title("Experimentation & Product Metrics Warehouse")
st.caption("Live dashboard reading directly from the dbt-built DuckDB warehouse")

con = duckdb.connect("../warehouse.duckdb", read_only=True)


funnel_summary = con.execute("""
    select
        max(case when funnel_step = 'page_view' then sessions_reached end) as page_views,
        max(case when funnel_step = 'checkout_complete' then sessions_reached end) as completions
    from fct_funnel_conversion
""").df().iloc[0]

overall_conversion = round(100.0 * funnel_summary["completions"] / funnel_summary["page_views"], 1)

experiment_summary = con.execute("""
    select
        max(case when variant = 'treatment' then session_completion_rate_pct end) as treatment_rate,
        max(case when variant = 'control' then session_completion_rate_pct end) as control_rate
    from fct_experiment_results
""").df().iloc[0]

uplift_pct = round(experiment_summary["treatment_rate"] - experiment_summary["control_rate"], 1)

col1, col2, col3, col4 = st.columns(4)
col1.metric("Total Sessions (page_view)", f"{int(funnel_summary['page_views']):,}")
col2.metric("Overall Funnel Conversion", f"{overall_conversion}%")
col3.metric("Treatment Completion Rate", f"{experiment_summary['treatment_rate']}%")
col4.metric("Experiment Uplift", f"+{uplift_pct}pp")

st.divider()


st.header("Funnel Conversion")

funnel_df = con.execute("""
    select funnel_step, step_order, sessions_reached
    from fct_funnel_conversion
    order by step_order
""").df()

fig = px.funnel(
    funnel_df,
    x="sessions_reached",
    y="funnel_step",
    title="Session-level funnel: page_view to checkout_complete",
)
st.plotly_chart(fig, use_container_width=True)

st.dataframe(funnel_df, use_container_width=True, hide_index=True)


st.header("Retention Cohorts")

retention_df = con.execute("""
    select cohort_week, weeks_since_signup, retention_pct
    from fct_retention_cohorts
    order by cohort_week, weeks_since_signup
""").df()

retention_df["cohort_week"] = retention_df["cohort_week"].astype(str)

fig_retention = px.line(
    retention_df,
    x="weeks_since_signup",
    y="retention_pct",
    color="cohort_week",
    title="Weekly retention by signup cohort",
    labels={"weeks_since_signup": "Weeks since signup", "retention_pct": "Retention %"},
)
st.plotly_chart(fig_retention, use_container_width=True)


st.header("Lifetime Value")

ltv_cohort_df = con.execute("""
    select cohort_week, cohort_size, avg_ltv_per_user, total_cohort_ltv
    from fct_ltv_by_cohort
    order by cohort_week
""").df()

ltv_cohort_df["cohort_week"] = ltv_cohort_df["cohort_week"].astype(str)

col1, col2 = st.columns(2)

with col1:
    fig_avg_ltv = px.bar(
        ltv_cohort_df,
        x="cohort_week",
        y="avg_ltv_per_user",
        title="Average LTV per user by cohort",
        labels={"cohort_week": "Cohort week", "avg_ltv_per_user": "Avg LTV ($)"},
    )
    st.plotly_chart(fig_avg_ltv, use_container_width=True)

with col2:
    fig_total_ltv = px.bar(
        ltv_cohort_df,
        x="cohort_week",
        y="total_cohort_ltv",
        title="Total revenue by cohort",
        labels={"cohort_week": "Cohort week", "total_cohort_ltv": "Total LTV ($)"},
    )
    st.plotly_chart(fig_total_ltv, use_container_width=True)


st.header("Experiment Results")

experiment_df = con.execute("""
    select variant, users, total_sessions, completed_sessions, session_completion_rate_pct
    from fct_experiment_results
    order by variant
""").df()

fig_experiment = px.bar(
    experiment_df,
    x="variant",
    y="session_completion_rate_pct",
    color="variant",
    title="Session-to-checkout-complete rate by experiment variant",
    labels={"variant": "Variant", "session_completion_rate_pct": "Completion rate (%)"},
    text="session_completion_rate_pct",
)
fig_experiment.update_traces(texttemplate="%{text}%", textposition="outside")
st.plotly_chart(fig_experiment, use_container_width=True)

st.dataframe(experiment_df, use_container_width=True, hide_index=True)
