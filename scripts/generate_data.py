"""
Generates synthetic product-analytics data for the
experimentation-product-metrics-warehouse project: 3,000 users,
90 days of events following a 5-step funnel, transactions, and a
single A/B experiment. Deliberately includes some messy/invalid
data so the downstream dbt test suite has real issues to catch.
"""

import csv
import random
import uuid
from datetime import datetime, timedelta
from faker import Faker

fake = Faker()
random.seed(42)      # makes results reproducible - same data every run
Faker.seed(42)       # keeps faker-generated fields (emails) reproducible too

N_USERS = 3000
DAYS = 90
START_DATE = datetime(2026, 3, 1)

FUNNEL_STEPS = ["page_view", "signup", "add_to_cart", "checkout_start", "checkout_complete"]
STEP_CONVERSION = [1.0, 0.55, 0.45, 0.60, 0.70]  # probability of reaching each step given the previous one

COUNTRIES = ["GB", "US", "DE", "FR", "IE", "NL", "ES"]
PLANS = ["free", "paid"]

users = []
events = []
transactions = []
experiment_assignments = []

# ---------- Users ----------
for i in range(1, N_USERS + 1):
    user_id = f"u_{i:05d}"
    signup_offset = random.randint(0, DAYS - 1)
    signup_date = START_DATE + timedelta(days=signup_offset)
    users.append({
        "user_id": user_id,
        "signup_date": signup_date.date().isoformat(),
        "country": random.choice(COUNTRIES),
        "plan_type": random.choices(PLANS, weights=[0.7, 0.3])[0],
        "email": fake.email() if random.random() > 0.02 else None,
    })
    
    # ---------- Experiment assignment (single experiment, 2 variants) ----------
    user_variant = None
    if random.random() < 0.8:  # not every user is enrolled in the test - 80% are
        user_variant = random.choice(["control", "treatment"])
        experiment_assignments.append({
            "user_id": user_id,
            "experiment_name": "checkout_redesign_v1",
            "variant": user_variant,
            "assigned_at": (signup_date + timedelta(days=random.randint(0, 3))).isoformat(),
        })
        
    # ---------- Events: simulate 1-4 "sessions" per user over the following weeks ----------
    n_sessions = random.randint(1, 4)
    is_treatment = user_variant == "treatment"  # treatment users get a small real conversion boost below

    for s in range(n_sessions):
        session_start = signup_date + timedelta(
            days=random.randint(0, max(DAYS - signup_offset - 1, 0)),
            hours=random.randint(8, 22),
            minutes=random.randint(0, 59),
        )
        t = session_start
        step_conv = STEP_CONVERSION.copy()
        if is_treatment:
            step_conv[4] = min(step_conv[4] + 0.12, 0.95)   # +12pp at checkout only, for treatment users

        for idx, step in enumerate(FUNNEL_STEPS):
            if idx > 0 and random.random() > step_conv[idx]:
                break   # user drops off the funnel for this session
            t = t + timedelta(seconds=random.randint(15, 240))
            events.append({
                "event_id": str(uuid.uuid4()),
                "user_id": user_id,
                "event_name": step,
                "event_timestamp": t.isoformat(sep=" "),
            })

            if step == "checkout_complete":
                transactions.append({
                    "transaction_id": str(uuid.uuid4()),
                    "user_id": user_id,
                    "transaction_timestamp": t.isoformat(sep=" "),
                    "amount": round(random.uniform(8.0, 220.0), 2),
                    "status": random.choices(
                        ["completed", "refunded", "failed"], weights=[0.9, 0.05, 0.05]
                    )[0],
                })
    

# ---------- Inject deliberate messiness for the test suite to catch ----------
# 1. A handful of duplicate event rows - simulates a tracking pixel double-firing
for _ in range(15):
    events.append(dict(random.choice(events)))

# 2. A few transactions with negative amounts - simulates a billing bug
for _ in range(5):
    bad = dict(random.choice(transactions))
    bad["transaction_id"] = str(uuid.uuid4())
    bad["amount"] = round(random.uniform(-50.0, -1.0), 2)
    transactions.append(bad)

# 3. A few orphaned events (user_id not present in users) -- simulates
#    upstream tracking bugs that referential-integrity tests should catch
for _ in range(8):
    events.append({
        "event_id": str(uuid.uuid4()),
        "user_id": f"u_ghost_{random.randint(1,999)}",
        "event_name": random.choice(FUNNEL_STEPS),
        "event_timestamp": fake.date_time_between(start_date="-90d").isoformat(sep=" "),
    })

random.shuffle(events)

# Writes a list of dicts to a CSV file with a header row.
def write_csv(path, rows, fieldnames):
    with open(path, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


write_csv("data/users.csv", users, ["user_id", "signup_date", "country", "plan_type", "email"])
write_csv("data/events.csv", events, ["event_id", "user_id", "event_name", "event_timestamp"])
write_csv("data/transactions.csv", transactions,
          ["transaction_id", "user_id", "transaction_timestamp", "amount", "status"])
write_csv("data/experiment_assignments.csv", experiment_assignments,
          ["user_id", "experiment_name", "variant", "assigned_at"])

print(f"users:                   {len(users):,}")
print(f"events:                  {len(events):,}")
print(f"transactions:            {len(transactions):,}")
print(f"experiment_assignments:  {len(experiment_assignments):,}")