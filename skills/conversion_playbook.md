---
name: instantlog_conversion_playbook
description: |
  Use this skill when the Developer says things like:
  - "why aren't users converting?" / "why is conversion low?"
  - "what broke after the release?" / "check metrics after v2.1"
  - "analyze my funnel" / "investigate production errors"
  - "why are users dropping off?" / "find errors in prod"
  - /instantlog-conversion / /instantlog-release-check / /instantlog-errors
  A step-by-step playbook: fetch data via MCP → run funnel analysis → investigate
  drop-off users → fix code or toggle Remote Config flags.
---

# InstantLog — Conversion & Error Analysis Playbook

## When to Use This Skill

- Developer asks: "why aren't users converting / purchasing?"
- Developer asks: "what happened after I shipped v2.1.0?"
- There are error logs in production that need investigation
- The Developer wants to A/B test a paywall and measure the result

**Prerequisites**: `instantlog_mcp_data_access` skill must be active. MCP server connected with the project's API key.

**Separation of concerns**:

- **InstantLog service** = stores logs, aggregates, computes funnels and percentiles. Passive.
- **AI agent (you)** = requests data via MCP, reasons about it, edits the Developer's local source files, or sets Remote Config flags.

---

## Phase 1 — Reconnaissance (always start here)

### 1.1 — Get overall scale

```
Tool: get_project_stats
```

Note `total_users`, `total_logs`, `total_errors`. If `total_users < 100`, warn the Developer that funnel data may not be statistically reliable.

### 1.2 — Discover events

```
Tool: get_event_names
```

This is the most important step. Read the top 50 events. Identify:

- Which events form the main conversion funnel
- Whether naming is consistent (inconsistent naming = broken analytics)

### 1.3 — Discover metadata dimensions

```
Tool: get_metadata_keys
```

Focus on keys where `isHighCardinality: false` — these are the useful filter and group-by dimensions (e.g. `platform`, `app_version`, `paywall_variant`).

### 1.4 — Triage active errors

```
Tool: get_logs
Params: { level: "error", limit: 100 }
```

Group errors by `content`. Any error appearing > 5 times is an action item.

---

## Phase 2 — Funnel Analysis

### 2.1 — Identify the funnel

From `get_event_names`, pick the two events that define the conversion goal:

- Top-of-funnel: the step every user passes through (e.g. "Paywall Viewed")
- Bottom-of-funnel: the success event (e.g. "Purchase Succeeded")

### 2.2 — Run the funnel

```
Tool: run_analysis
```

```json
{
  "plan": {
    "blocks": [
      {
        "blockType": "step", "id": "s1", "displayName": "Paywall Viewed",
        "matcher": { "type": "content_contains", "value": "Paywall Viewed" }
      },
      {
        "blockType": "step", "id": "s2", "displayName": "Purchase Succeeded",
        "matcher": { "type": "content_contains", "value": "Purchase Succeeded" }
      },
      {
        "blockType": "time-range", "id": "tr1",
        "period1Start": "YYYY-MM-DD", "period1End": "YYYY-MM-DD"
      }
    ]
  }
}
```

Read the result:

- `summary.conversion_rate` = overall conversion (e.g. 0.08 = 8%)
- `summary.p50_ms` = median time from step A to step B
- `summary.a_count` / `summary.b_count` = how many users entered / completed the funnel

### 2.3 — Break down by segment

Add a `group-by` block using a key from `get_metadata_keys`:

```json
{ "blockType": "group-by", "id": "gb1", "dimensions": ["platform"] }
```

Try: `platform`, `app_version`, `paywall_variant`, `locale`, `user_segment`.

**Interpretation**:

- One platform at 50% lower conversion → likely a platform-specific bug
- One `app_version` with near-zero conversion → a regression in that release
- One `paywall_variant` worse than others → losing variant should be disabled

---

## Phase 3 — User Journey Investigation

For users who **dropped off** (reached step 1 but not step 2), use **exact** targeting:

### 3.1 — Get the exact drop-off users

```
Tool: get_dropoff_users
Params: {
  step_a_value: "Paywall Viewed",
  step_b_value: "Purchase Succeeded",
  from: "YYYY-MM-DD", to: "YYYY-MM-DD",
  window_hours: 24, limit: 20
}
```

Returns `dropoff_users` — the exact `user_uuid` list of people who hit step A but never step B. This is far more precise than filtering `get_users` manually.

Also note `dropoff_rate` from the result — if it's > 80%, there's a systemic problem (not just edge cases).

### 3.2 — Replay their journeys

For each `user_uuid` in `dropoff_users`:

```
Tool: get_user_journey
Params: { user_uuid: "<id from dropoff_users>", limit: 100 }
```

Look for:

- An `error` log immediately before the drop-off point
- `Purchase Initiated` present but `Purchase Succeeded` absent → payment failed silently
- User left and returned multiple times before giving up → confusing UX
- Specific OS/version pattern in their metadata

---

## Phase 4 — Root Cause & Code Fix

### 4.1 — Cluster errors

Group by `content`, `metadata.app_version`, `metadata.platform`, `metadata.screen`. A cluster that only appears on one version = regression.

### 4.2 — Locate the code

Search the Developer's codebase for:

- The exact string in the `content` field of the error log
- The surrounding error handler or try/catch
- The API call or validation that could be failing

### 4.3 — Apply the fix

- Fix the root cause directly in the source files
- **Do not remove existing error logs** — they confirm the fix works in production
- Add a more specific log near the fix to confirm recovery

### 4.4 — Immediate mitigation via Remote Config

If the fix requires a release and the problem is severe (e.g. broken paywall):

```
Tool: get_remote_config        ← read current flags first
Tool: set_remote_config_flag   ← toggle the problematic feature off
```

The Developer's app must already read this flag and act on it. This is zero-latency — no App Store review needed.

---

## Phase 5 — Post-Release Comparison

After shipping a new version, use `period2` to compare before vs. after:

```json
{
  "plan": {
    "blocks": [
      { "blockType": "step", "id": "s1", "displayName": "Paywall Viewed",
        "matcher": { "type": "content_contains", "value": "Paywall Viewed" } },
      { "blockType": "step", "id": "s2", "displayName": "Purchase Succeeded",
        "matcher": { "type": "content_contains", "value": "Purchase Succeeded" } },
      {
        "blockType": "time-range", "id": "tr1",
        "period1Start": "2025-01-15", "period1End": "2025-01-21",
        "period2Start": "2025-01-22", "period2End": "2025-01-28"
      }
    ]
  }
}
```

Read `delta.conversion_rate_rel`:

- Positive → conversion improved after release ✅
- Negative → conversion regressed → investigate with `get_logs` (level=error, from=release_date)

---

## Phase 6 — A/B Test Read-out

If the Developer ran two paywall variants tracked via `metadata.paywall_variant`:

Add a `group-by` on `paywall_variant` to the funnel. The winner has the higher `conversion_rate` in its breakdown row.

After the test:

- Use `set_remote_config_flag` to roll everyone to the winning variant
- Remove the losing variant from the codebase

---

## Summary Reference

| Phase | Goal | Tools |
|---|---|---|
| Reconnaissance | Understand what data exists | `get_project_stats`, `get_event_names`, `get_metadata_keys` |
| Error Triage | Find active production errors | `get_logs` (level=error) |
| Funnel Analysis | Measure conversion rate | `run_analysis` |
| Segmentation | Find worst-performing segment | `run_analysis` + `group-by` |
| User Journey | Understand why they dropped off | `get_users`, `get_user_journey` |
| Code Fix | Fix root cause | Edit source files directly |
| Immediate Mitigation | Disable broken feature without a release | `get_remote_config`, `set_remote_config_flag` |
| Release Check | Compare before vs. after | `run_analysis` with `period2` |
