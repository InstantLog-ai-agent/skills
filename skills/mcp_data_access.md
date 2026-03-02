---
name: sensorcore_mcp_data_access
description: |
  Use this skill when the Developer says things like:
  - "analyze my logs" / "check what's happening in production"
  - "what errors do I have?" / "what broke after the release?"
  - "why aren't users converting?" / "check my funnel"
  - "are there anomalies?" / "who are my problem users?"
  - "compare segments" / "iOS vs Android" / "version 2.0 vs 2.1"
  - "forecast" / "predict" / "what will happen next week?"
  - "find bug patterns" / "where does this error happen?"
  - "user flow" / "how do users navigate?"
  - "connect to SensorCore" / "query SensorCore data"
  - /sensorcore-analyze / /sensorcore-errors / /sensorcore-conversion / /sensorcore-release-check
  Complete reference of all 21 SensorCore MCP tools: discovery, data access, ML analytics, and remote config.
---

# SensorCore — MCP Tool Reference (Complete)

## Connection

**MCP Endpoint**: `POST/GET/DELETE https://api.sensorcore.dev/api/mcp/sse`
Authentication: `x-api-key: <PROJECT_API_KEY>` header.
Transport: **Streamable HTTP** (MCP spec 2025-03-26).

```json
{
  "mcpServers": {
    "sensorcore": {
      "url": "https://api.sensorcore.dev/api/mcp/sse",
      "headers": { "x-api-key": "sc_YOUR_PROJECT_API_KEY" }
    }
  }
}
```

For local development: use `http://localhost:3000/api/mcp/sse`.

---

## Always Start Here

Every analysis session begins with discovery. These 3 calls tell the agent what data exists:

```
1. get_project_stats     → data volume (users, logs, errors)
2. get_event_names       → what events exist, ranked by frequency (default: top 50, max 100)
3. get_metadata_keys     → available dimensions (platform, app_version, country...)
```

Then branch based on the Developer's question. See the `analytics_combinator` skill for decision trees and recipes.

---

## Tool Catalogue — 21 Tools

> **Defaults**: Every optional parameter has a server-side default (shown in tables below). If you omit a parameter, the default is used automatically. Always check the default before adding explicit values — most defaults are already optimal.

### 🔍 Discovery (3 tools)

#### `get_event_names`

**What**: Returns all unique event `content` values ranked by frequency.
**When**: Always call FIRST before any analysis. This is how the agent learns what events exist.

```json
{ "name": "get_event_names", "arguments": { "limit": 50 } }
```

| Param | Type | Default | Notes |
|---|---|---|---|
| `limit` | number | 50 | Max 100 |

**Returns**: `{ events: [{ name, count }], total_distinct_events }` — sorted by frequency desc.

---

#### `get_metadata_keys`

**What**: Returns all metadata keys with cardinality and sample values.
**When**: Before any `group-by`, `filter`, or `segment_comparison`. The agent needs to know available dimensions.

```json
{ "name": "get_metadata_keys", "arguments": {} }
```

**Returns**: `{ keys: [{ key, cardinality, samples, isHighCardinality }] }` — low-cardinality keys first (good for group-by).

**Key insight**: Keys with `isHighCardinality: false` are useful for segmentation (e.g. `platform`, `app_version`, `country`). High-cardinality keys (e.g. `user_id`) are not.

---

#### `get_project_stats`

**What**: Basic project statistics.
**When**: First call — understand the scale of data before diving in.

```json
{ "name": "get_project_stats", "arguments": {} }
```

**Returns**: `{ project: { id, name, has_errors }, stats: { total_users, total_logs, total_errors } }`.

**Decision point**: If `total_users < 100`, warn the Developer that statistical analyses may not be reliable.

---

### 📋 Data Access (4 tools)

#### `get_logs`

**What**: Fetch raw log entries with filters.
**When**: Spot-checking specific errors, verifying event content, triage.

```json
{
  "name": "get_logs",
  "arguments": {
    "limit": 100,
    "level": "error",
    "from": "2026-02-01",
    "to": "2026-02-25",
    "user_uuid": "optional-end-user-id"
  }
}
```

| Param | Type | Default | Notes |
|---|---|---|---|
| `limit` | number | 30 | Max 200 |
| `level` | string | — | `info` \| `warning` \| `error` \| `messages` |
| `from` | string | — | `YYYY-MM-DD` inclusive |
| `to` | string | — | `YYYY-MM-DD` inclusive |
| `user_uuid` | string | — | Filter to one End-User |

**Returns**: Array of `{ content, level, user_uuid, metadata, created_at }`.

> ⚠️ Don't use `get_logs` for aggregations — use ML tools instead. Raw logs are for spot-checking.

---

#### `get_users`

**What**: List End-Users with their UUIDs.
**When**: Finding user identifiers for `get_user_journey`. Supports search and pagination.

```json
{ "name": "get_users", "arguments": { "limit": 20, "offset": 0, "search": "optional" } }
```

| Param | Type | Default | Notes |
|---|---|---|---|
| `limit` | number | 20 | Max 100 |
| `offset` | number | 0 | Pagination |
| `search` | string | — | Filter by user_uuid or metadata content |

**Returns**: `{ users: [{ user_uuid, metadata, last_seen_at }], total }`.

---

#### `get_user_journey`

**What**: Full chronological log sequence for one End-User.
**When**: Understanding what a user did before an error or drop-off. Always use with a specific `user_uuid` from `get_dropoff_users` or `get_users`.

```json
{ "name": "get_user_journey", "arguments": { "user_uuid": "abc-123", "limit": 100 } }
```

| Param | Type | Required | Notes |
|---|---|---|---|
| `user_uuid` | string | ✅ | The End-User's external_uuid |
| `limit` | number | ❌ | Max 200. Default 50 |

**Returns**: Logs ordered oldest→newest for that End-User.

**What to look for**:

- An `error` log right before the drop-off point
- `Purchase Initiated` present but `Purchase Succeeded` absent → silent payment failure
- Repeated back-and-forth between screens → confusing UX
- Specific metadata patterns (OS version, device, country)

---

#### `get_dropoff_users`

**What**: Returns End-Users who completed step A but NOT step B within attribution window.
**When**: Investigating funnel drop-offs. Always call BEFORE `get_user_journey` — this gives you the exact users to investigate.

```json
{
  "name": "get_dropoff_users",
  "arguments": {
    "step_a_value": "Paywall Viewed",
    "step_b_value": "Purchase Succeeded",
    "from": "2026-02-01",
    "to": "2026-02-25",
    "window_hours": 24,
    "limit": 20
  }
}
```

| Param | Type | Required | Notes |
|---|---|---|---|
| `step_a_value` | string | ✅ | Content substring for step A (case-insensitive LIKE) |
| `step_b_value` | string | ✅ | Content substring for step B |
| `from` | string | ✅ | Start date `YYYY-MM-DD` |
| `to` | string | ✅ | End date `YYYY-MM-DD` inclusive |
| `window_hours` | number | ❌ | Attribution window. Default 24h |
| `limit` | number | ❌ | Max 100. Default 20 |

**Returns**:

```json
{
  "dropoff_users": [{ "user_uuid": "abc-123", "first_step_a_at": "2026-02-15T10:23:00" }],
  "total_step_a": 842,
  "total_dropoffs": 18,
  "dropoff_rate": 0.021
}
```

**Interpretation** (context-dependent thresholds):

| Funnel Type | Healthy | Investigate | Critical |
|---|---|---|---|
| Paywall → Purchase | < 60% | 60–80% | > 80% |
| Sign Up → Activation | < 30% | 30–50% | > 50% |
| General (any 2 steps) | < 40% | 40–60% | > 60% |

> ⚠️ A 40–50% dropoff on a payment step is already a serious problem. Don't wait for 80% to investigate.

- Feed `user_uuid` values into `get_user_journey` to understand WHY they dropped

---

### 🧠 ML Analytics (12 tools)

All ML tools run server-side. The agent receives compact results, not raw data.

#### `get_error_clusters`

**What**: Groups error logs into clusters by content similarity. Each cluster: count, affected users, first/last seen, metadata patterns.
**When**: "What errors are happening?" — always better than manually reading `get_logs(level=error)`.

```json
{ "name": "get_error_clusters", "arguments": { "days": 7, "limit": 10 } }
```

| Param | Type | Default |
|---|---|---|
| `days` | number | 7 |
| `limit` | number | 10 |

**Returns**: Clusters sorted by count. Each cluster has `content_pattern`, `count`, `affected_users`, `first_seen`, `last_seen`, `metadata_patterns`.

**Key insight**: `metadata_patterns` tells you if the error is platform-specific (e.g. "85% on iOS 17.4").

---

#### `get_anomalies`

**What**: Detects anomalous End-Users using Isolation Forest ML algorithm.
**When**: "Are there any weird users?" / "Who's causing problems?"

```json
{ "name": "get_anomalies", "arguments": { "days": 7 } }
```

| Param | Type | Default |
|---|---|---|
| `days` | number | 7 |

**Returns**: Users ranked by anomaly score with reasons (e.g. "unusually high error rate", "abnormal event pattern").

---

#### `get_forecast`

**What**: Prophet time-series forecast. Predicts future trend and detects if current values deviate from predictions.
**When**: "Will purchases grow?" / "Is the error rate abnormal?" / pre-release baseline.

```json
{
  "name": "get_forecast",
  "arguments": {
    "event_name": "Purchase Succeeded",
    "history_days": 60,
    "forecast_days": 7
  }
}
```

| Param | Type | Required | Default |
|---|---|---|---|
| `event_name` | string | ✅ | — |
| `history_days` | number | ❌ | 30 |
| `forecast_days` | number | ❌ | 7 |

**Returns**: Daily `yhat` + `yhat_lower` / `yhat_upper` bounds + anomalies if current values deviate from prediction.

---

#### `get_statistical_test`

**What**: Statistical significance test comparing a metric between two time periods. Returns p-value, z-score, human-readable message.
**When**: "Did the release change anything?" / "Is this drop significant or just noise?"

```json
{
  "name": "get_statistical_test",
  "arguments": {
    "event_name": "Purchase Succeeded",
    "period1_start": "2026-02-01",
    "period1_end": "2026-02-10",
    "period2_start": "2026-02-11",
    "period2_end": "2026-02-20"
  }
}
```

| Param | Type | Required |
|---|---|---|
| `event_name` | string | ✅ |
| `period1_start` | string | ✅ |
| `period1_end` | string | ✅ |
| `period2_start` | string | ✅ |
| `period2_end` | string | ✅ |

**Returns**: `{ p_value, is_significant, change_pct, z_score, message }`.

**Interpretation**: `p_value < 0.05` = statistically significant change, not random noise.

---

#### `get_bug_detective`

**What**: Decision Tree that finds multi-factor conditions for errors. Example: "purchase_failed occurs 85% of the time on iOS 17.4 + country=FR".
**When**: "On which devices/versions/countries does this error happen?" / "Why does this bug reproduce?"

```json
{
  "name": "get_bug_detective",
  "arguments": {
    "error_content": "payment_failed",
    "dimensions": "device,os_version,country",
    "days": 30,
    "max_depth": 4,
    "min_samples": 5
  }
}
```

| Param | Type | Default | Notes |
|---|---|---|---|
| `days` | number | 30 | — |
| `error_content` | string | — | Specific error to investigate. Omit for all errors |
| `dimensions` | string | auto-detect | Comma-separated metadata keys |
| `max_depth` | number | 4 | Decision tree depth (2–6) |
| `min_samples` | number | 5 | Min samples per leaf |

**Returns**: Decision tree rules with `lift`, `confidence`, and affected user counts.

---

#### `get_cohort_analysis`

**What**: Groups users into cohorts by ANY dimension and tracks metrics over time.
**When**: "Are new users better or worse?" / "Retention by version?" / "Revenue per country cohort?"

```json
{
  "name": "get_cohort_analysis",
  "arguments": {
    "days": 60,
    "cohort_by": "app_version",
    "metric": "retention"
  }
}
```

| Param | Type | Default | Notes |
|---|---|---|---|
| `days` | number | 60 | — |
| `cohort_by` | string | `week` | `week`, `month`, `app_version`, `country`, or any metadata key |
| `metric` | string | `retention` | `retention`, `events`, `revenue`, `errors` |

**Returns**: Per-cohort metrics with comparison summary.

---

#### `get_association_rules`

**What**: Discovers event correlations. "Users who do X have Y% probability of doing Z". Apriori-like algorithm.
**When**: "What predicts purchase?" / "What actions lead to conversion?"

```json
{
  "name": "get_association_rules",
  "arguments": {
    "target_event": "Purchase Succeeded",
    "min_confidence": 0.3,
    "min_lift": 1.2,
    "days": 30
  }
}
```

| Param | Type | Default | Notes |
|---|---|---|---|
| `days` | number | 30 | — |
| `target_event` | string | — | Find rules leading to this event. Omit to discover all rules |
| `min_support` | number | 0.05 | Fraction of users with both events (0.01–0.5) |
| `min_confidence` | number | 0.3 | Probability P(B\|A) (0.1–1.0) |
| `min_lift` | number | 1.2 | How much more likely (1.0–10.0) |

**Returns**: Rules with `support`, `confidence`, `lift`. Example: "Users who `tutorial_complete` + `feature_x_used` purchase with 67% probability (lift 3.2x)".

---

#### `get_user_flow`

**What**: Transition graph of user navigation. Discovers common paths, bottlenecks (high exit rate), generates Mermaid diagram.
**When**: "How do users navigate the app?" / "Where's the bottleneck?"

```json
{
  "name": "get_user_flow",
  "arguments": {
    "days": 30,
    "start_event": "App Launched",
    "max_steps": 6
  }
}
```

| Param | Type | Default | Notes |
|---|---|---|---|
| `days` | number | 30 | — |
| `max_steps` | number | 6 | Steps to track per user (3–10) |
| `start_event` | string | — | Start from this event. Omit for all paths |
| `event_filter` | string | — | Only include matching events |

**Returns**: `{ nodes, edges, top_paths, bottlenecks, mermaid_diagram }`.

**Key insight**: `bottlenecks` lists events with high exit rate — these are where users leave the app.

---

#### `get_change_points`

**What**: Detects moments when a metric permanently changed (structural break, not temporary spike). Uses PELT algorithm.
**When**: "When exactly did conversion drop?" / "When did errors start increasing?"

```json
{
  "name": "get_change_points",
  "arguments": {
    "event_name": "Purchase Succeeded",
    "days": 60,
    "metric": "count",
    "sensitivity": "medium"
  }
}
```

| Param | Type | Required | Default |
|---|---|---|---|
| `event_name` | string | ✅ | — (use `*` for all events) |
| `days` | number | ❌ | 60 |
| `metric` | string | ❌ | `count` (`count`, `error_rate`, `unique_users`) |
| `sensitivity` | string | ❌ | `medium` (`low`, `medium`, `high`) |

**Returns**: Detected change points with `date`, `before_avg`, `after_avg`, `confidence`.

Example: "Since Feb 15, permanent decrease. Before: avg 42/day, after: avg 28/day, confidence 0.95".

---

#### `get_segment_comparison`

**What**: Statistically compares ANY two user segments across all metrics. Mann-Whitney U + Cohen's d.
**When**: "iOS vs Android?" / "Germany vs USA?" / "Version 2.0 vs 2.1?"

```json
{
  "name": "get_segment_comparison",
  "arguments": {
    "segment_field": "country",
    "segment_a": "DE",
    "segment_b": "US",
    "days": 30
  }
}
```

| Param | Type | Required |
|---|---|---|
| `segment_field` | string | ✅ (any metadata key) |
| `segment_a` | string | ✅ |
| `segment_b` | string | ✅ |
| `days` | number | ❌ (default 30) |

**Returns**: Per-metric comparison with `p_value`, `effect_size` (Cohen's d), `winner`.

**Interpretation**: `p_value < 0.05` + `effect_size > 0.5` = meaningful difference, not noise.

---

#### `get_smart_alerts`

**What**: Runs ALL ML analyzers and returns prioritized alerts with executive summary. The "one call to see everything".
**When**: "What's happening in the project?" / "Any problems?" / health check.

```json
{ "name": "get_smart_alerts", "arguments": { "days": 7 } }
```

| Param | Type | Default |
|---|---|---|
| `days` | number | 7 (max 90) |

**Returns**: Prioritized alert list (critical → warning → info) covering error clusters, anomalies, bug patterns, trend changes, and opportunities + executive summary.

> This is the best starting tool for open-ended investigation. From its output, drill deeper with specific tools.

---

#### `run_behavioral_analysis`

**What**: Splits users into two cohorts and compares behavior using ML (Random Forest) or statistical tests (Mann-Whitney U).
**When**: "What do buyers do differently?" / "Compare premium vs free users"

**Important**: Always call `get_event_names` first — you need to pick features from the event list.

```json
{
  "name": "run_behavioral_analysis",
  "arguments": {
    "cohort_a": {
      "did_event": "Purchase Succeeded"
    },
    "cohort_b": {
      "did_event": "Paywall Viewed",
      "not_event": "Purchase Succeeded"
    },
    "features": [
      { "type": "event_count", "event": "tutorial_complete" },
      { "type": "event_count", "event": "feature_x_used" },
      { "type": "event_presence", "event": "referral_clicked" },
      { "type": "time_to_event", "event": "first_purchase" }
    ],
    "method": "ml",
    "days": 60
  }
}
```

**Cohort definition** — each cohort uses:

| Field | Description |
|---|---|
| `did_event` | Include users who have this event (content_contains). `*` = all users |
| `not_event` | Exclude users who have this event |
| `metadata_filter` | Filter by metadata key=value, e.g. `{"country": "US"}` |

**Feature types**:

| Type | What it measures |
|---|---|
| `event_count` | How many times the user did this event |
| `event_presence` | 0 or 1 — did they ever do it? |
| `time_to_event` | Hours from user's first event to this event |

**Methods**:

| Method | Algorithm | Best for |
|---|---|---|
| `ml` | Random Forest | Feature importance ranking — "which behavior matters most?" |
| `statistical` | Mann-Whitney U | Per-feature p-values — "is the difference significant?" |

**Returns**: Feature importances (ml) or per-feature p-values (statistical) + cohort sizes + summary.

---

### ⚙️ Remote Config (2 tools)

#### `get_remote_config`

**What**: Read all current flags.
**When**: Before setting any flags — understand what exists first.

```json
{ "name": "get_remote_config", "arguments": {} }
```

**Returns**: JSON object with all flag key/value pairs. Empty `{}` if none.

---

#### `set_remote_config_flag`

**What**: Set or delete a single Remote Config flag. The app reads the updated value immediately — no release needed.
**When**: Disabling broken features, enabling A/B tests, tuning parameters.

```json
{
  "name": "set_remote_config_flag",
  "arguments": { "key": "show_experimental_paywall", "value": "false" }
}
```

| Param | Type | Required | Notes |
|---|---|---|---|
| `key` | string | ✅ | Flag identifier |
| `value` | string | ❌ | Omit or `null` to **delete** the flag |

**Value auto-parsing**: `"true"`/`"false"` → boolean, `"42"` → number, else → string.

**Returns**: `{ success: true, config: { ...all_current_flags } }`.

**Workflow**: Always `get_remote_config` → `set_remote_config_flag` → `get_remote_config` (verify).

---

## MCP Prompts (Built-in Workflows)

| Prompt | What it does |
|---|---|
| `analyze_errors` | Fetches error clusters → anomalies → user journeys → suggests code fixes |
| `improve_conversion` | Smart alerts → events → funnel → drop-offs → user journeys → fixes |
| `post_release_check` | Smart alerts → error clusters → statistical test → forecast → regression detection |

These are available as MCP prompts. The agent can invoke them directly, or follow the equivalent steps manually for more control.
