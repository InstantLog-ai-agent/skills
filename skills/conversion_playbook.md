---
name: sensorcore_conversion_playbook
description: |
  Use this skill when the Developer says things like:
  - "why aren't users converting?" / "why is conversion low?"
  - "what broke after the release?" / "check metrics after v2.1"
  - "analyze my funnel" / "investigate production errors"
  - "why are users dropping off?" / "find errors in prod"
  - "what changed?" / "is this drop significant?"
  - /sensorcore-conversion / /sensorcore-release-check / /sensorcore-errors
  Step-by-step playbook: discover data → analyze with ML tools → investigate drop-offs →
  find root cause in source code → fix code or toggle Remote Config.
---

# SensorCore — Conversion & Error Analysis Playbook

## When to Use This Skill

- Developer asks: "why aren't users converting / purchasing?"
- Developer asks: "what happened after I shipped v2.1.0?"
- There are error logs in production that need investigation
- Developer wants to compare paywall variants (A/B test)

**Prerequisites**: `sensorcore_mcp_data_access` skill must be active. MCP server connected.

**Key Principle**: You are a **Senior Data Scientist & Product Manager**, not a bug fixer.

- After analysis: **write the Executive Report FIRST** (use template from `analytics_combinator.md`)
- In every finding, connect technical metrics to **money**: "Conversion dropped 5% → losing ~$X/week"
- MCP tools tell you WHAT is wrong → source code tells you WHERE → report explains **WHY it matters**
- Do NOT jump to code fixes. The insight IS the product
- If data is sparse, say so: "Not enough data for 100% confidence, but trend points to X"
- Verify anomalies: check `get_user_journey` for minimum 3 real user paths before reporting
- The system is **language agnostic** — any stack can send logs, don't assume Swift-only

---

## Phase 1 — Reconnaissance (always start here)

### 1.1 — Quick Health Check

```
Tool: get_smart_alerts
Params: { days: 7 }
```

This single call runs all ML analyzers and returns prioritized alerts. Read the executive summary first — it often answers the Developer's question immediately.

### 1.2 — Discover Events

```
Tool: get_event_names
Params: { limit: 50 }
```

Read the top 50 events. Identify:

- Which events form the main conversion funnel (e.g. "Paywall Viewed" → "Purchase Succeeded")
- Whether naming is consistent (inconsistent = broken analytics)
- Which events could be useful as `features` in `run_behavioral_analysis`

### 1.3 — Discover Dimensions

```
Tool: get_metadata_keys
```

Focus on keys where `isHighCardinality: false` — these are useful for segmentation: `platform`, `app_version`, `paywall_variant`, `locale`, `country`.

### 1.4 — Triage Errors

```
Tool: get_error_clusters
Params: { days: 7 }
```

Each cluster shows: count, affected users, metadata patterns. Any cluster affecting > 5 users is an action item.

> Don't use `get_logs(level=error)` for this — `get_error_clusters` groups and counts server-side.

---

## Phase 2 — Conversion Analysis

### 2.1 — Identify the funnel

From `get_event_names`, pick the two events that define the conversion goal:

- Top-of-funnel: the step every user passes through (e.g. "Paywall Viewed")
- Bottom-of-funnel: the success event (e.g. "Purchase Succeeded")

### 2.2 — Check for structural changes

```
Tool: get_change_points
Params: { event_name: "Purchase Succeeded", days: 60, metric: "count" }
```

This tells you WHEN exactly conversion changed. If there's a change point:

- Note the date — it anchors the entire investigation
- Check if a release or code change happened around that date

### 2.3 — Verify statistical significance

```
Tool: get_statistical_test
Params: {
  event_name: "Purchase Succeeded",
  period1_start: "before_change_point",
  period1_end: "change_point_date",
  period2_start: "change_point_date",
  period2_end: "today"
}
```

If `p_value < 0.05` → the change is statistically significant, not random noise.
If `p_value > 0.05` → the fluctuation is within normal range.

### 2.4 — Break down by segment

```
Tool: get_segment_comparison
Params: { segment_field: "app_version", segment_a: "2.0", segment_b: "2.1", days: 30 }
```

Try different segment fields:

- `app_version` → regression in a specific release?
- `platform` → iOS vs Android issue?
- `country` → localization bug?
- `paywall_variant` → losing AB variant?

**Interpretation**:

- One segment with significantly lower conversion (`p_value < 0.05`) → segment-specific bug
- `effect_size > 0.5` → meaningful difference, not just noise

---

## Phase 3 — User Journey Investigation

### 3.1 — Get exact drop-off users

```
Tool: get_dropoff_users
Params: {
  step_a_value: "Paywall Viewed",
  step_b_value: "Purchase Succeeded",
  from: "change_point_date", to: "today",
  window_hours: 24
}
```

Returns the exact `user_uuid` list of people who hit step A but never step B.

- `dropoff_rate > 0.80` → systemic problem
- `dropoff_rate < 0.05` → funnel is healthy

### 3.2 — Replay journeys

For 2–3 users from `dropoff_users`:

```
Tool: get_user_journey
Params: { user_uuid: "<id from step 3.1>", limit: 100 }
```

Look for:

- An `error` log right before the drop-off → payment failed silently
- `Purchase Initiated` present but `Purchase Succeeded` absent → payment processing bug
- User revisits the same screen multiple times → confusing UX
- Specific metadata patterns (OS, device) that match `get_bug_detective` findings

---

## Phase 4 — Root Cause & Code Fix

### 4.1 — ML-powered root cause analysis

If errors are the likely cause:

```
Tool: get_bug_detective
Params: { error_content: "<error from journey>", dimensions: "device,os_version,app_version" }
```

Decision Tree output tells you: "This error occurs 85% of the time under [conditions]".

If behavioral differences are the likely cause:

```
Tool: run_behavioral_analysis
Params: {
  cohort_a: { did_event: "Purchase Succeeded" },
  cohort_b: { did_event: "Paywall Viewed", not_event: "Purchase Succeeded" },
  features: [ ...top events from get_event_names as event_count ],
  method: "ml"
}
```

Feature importances tell you which behaviors separate buyers from non-buyers.

### 4.2 — Locate the code

Search the Developer's codebase for:

1. The exact `content` string from the error log or drop-off event
2. The surrounding error handler / try-catch / API call
3. Platform-specific conditions that match ML findings (e.g. `if platform == "ios"`)
4. The log placement — verify metadata matches what analytics sees

### 4.3 — Apply the fix

- Fix the root cause directly in source files
- **Do NOT remove existing error logs** — they confirm the fix works in production
- Add a more specific log near the fix to track recovery
- Follow the `event_taxonomy` skill for naming

### 4.4 — Immediate mitigation via Remote Config

If the fix requires a release and the problem is severe:

```
Tool: get_remote_config        ← read current flags first
Tool: set_remote_config_flag   ← toggle the broken feature off
```

Search the codebase to confirm the app reads this flag. No App Store review needed.

---

## Phase 5 — Post-Release Verification

After shipping a fix:

### 5.1 — Statistical check

```
Tool: get_statistical_test
Params: {
  event_name: "Purchase Succeeded",
  period1_start: "before_fix",  period1_end: "fix_release_date",
  period2_start: "fix_release_date", period2_end: "today"
}
```

Positive `change_pct` + `is_significant: true` → fix worked.

### 5.2 — Error cluster check

```
Tool: get_error_clusters
Params: { days: 3 }
```

The original error cluster should have reduced count or disappeared.

### 5.3 — Forecast check

```
Tool: get_forecast
Params: { event_name: "Purchase Succeeded", history_days: 60, forecast_days: 7 }
```

Current values should be within `yhat_lower`–`yhat_upper` range (no anomaly flagged).

---

## Phase 6 — A/B Test Read-out

### 6.1 — Compare variants

```
Tool: get_segment_comparison
Params: { segment_field: "paywall_variant", segment_a: "A", segment_b: "B", days: 14 }
```

Winner = higher conversion_rate with `p_value < 0.05`.

### 6.2 — Understand WHY the winner wins

```
Tool: run_behavioral_analysis
Params: {
  cohort_a: { metadata_filter: { paywall_variant: "A" } },
  cohort_b: { metadata_filter: { paywall_variant: "B" } },
  features: [ ...key events ],
  method: "statistical"
}
```

Per-feature p-values show WHERE the behavior differs between variants.

### 6.3 — Roll out the winner

```
Tool: set_remote_config_flag
Params: { key: "paywall_variant", value: "B" }
```

Then remove the losing variant code from the codebase.

---

## Quick Reference

| Phase | Goal | Primary Tools | Source Code |
|---|---|---|---|
| Health Check | Quick overview | `get_smart_alerts` | — |
| Discovery | What data exists | `get_event_names`, `get_metadata_keys`, `get_project_stats` | Verify log placements match |
| Error Triage | Find active errors | `get_error_clusters` | Find error handlers |
| Change Detection | When did it break | `get_change_points`, `get_statistical_test` | Check git history |
| Segmentation | Which segment is worst | `get_segment_comparison` | Check platform code paths |
| User Journey | Why they dropped off | `get_dropoff_users`, `get_user_journey` | Find the drop-off screen code |
| Bug Root Cause | Why does error happen | `get_bug_detective` | Fix the conditional logic |
| Behavioral | What predicts conversion | `run_behavioral_analysis`, `get_association_rules` | Promote winning features |
| Code Fix | Fix root cause | — | Apply the fix directly |
| Immediate Mitigation | Disable broken feature | `get_remote_config`, `set_remote_config_flag` | Verify flag is consumed |
| Release Verification | Did fix work | `get_statistical_test`, `get_forecast` | — |
| AB Test | Which variant wins | `get_segment_comparison`, `run_behavioral_analysis` | Remove losing variant |
