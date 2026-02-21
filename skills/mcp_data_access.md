---
name: instantlog_mcp_data_access
description: |
  Use this skill when the Developer says things like:
  - "analyze my logs" / "check what's happening in production"
  - "what errors do I have?" / "what broke after the release?"
  - "why aren't users converting?" / "check my funnel"
  - "connect to InstantLog" / "query InstantLog data"
  - /instantlog-analyze / /instantlog-errors / /instantlog-conversion / /instantlog-release-check
  Teaches the agent how to connect to the InstantLog MCP server and use its tools
  to fetch logs, run funnel analysis, investigate drop-offs, and toggle Remote Config flags.
---

# InstantLog — MCP Data Access Skill

## Overview

InstantLog exposes a **Model Context Protocol (MCP) server** so that AI agents can directly query log data on behalf of the Developer. The agent reads data, reasons about it, and then acts — by editing the Developer's local source files or toggling Remote Config flags.

**MCP Endpoint**: `POST/GET/DELETE https://api.instantlog.io/api/mcp/sse`

Authentication: `x-api-key: <PROJECT_API_KEY>` header (same key used for log ingestion).

> Transport: **Streamable HTTP** (MCP spec 2025-03-26). The agent's MCP client must support this transport.

### Add to Agent MCP Config

```json
{
  "mcpServers": {
    "instantlog": {
      "url": "https://api.instantlog.io/api/mcp/sse",
      "headers": { "x-api-key": "il_YOUR_PROJECT_API_KEY" }
    }
  }
}
```

For local development: use `http://localhost:3000/api/mcp/sse`.

---

## Recommended Start Sequence

Always begin a session with this order:

```
1. get_project_stats     → understand data volume
2. get_event_names       → discover what events exist
3. get_metadata_keys     → discover filter/group-by dimensions
```

Then branch based on the Developer's goal.

---

## Available Tools

### `get_event_names`

**Use first.** Returns all unique event names ranked by frequency.

```json
{ "name": "get_event_names", "arguments": { "limit": 50 } }
```

| Parameter | Type | Default | Notes |
|---|---|---|---|
| `limit` | number | 50 | Max 100 |

**Returns**: `{ events: [{ name, count }], total_distinct_events }` — sorted by frequency desc.

---

### `get_metadata_keys`

Returns all metadata keys with cardinality and sample values. Use to determine what dimensions are available for filtering and group-by.

```json
{ "name": "get_metadata_keys", "arguments": {} }
```

**Returns**: `{ keys: [{ key, cardinality, samples, isHighCardinality }] }` — low-cardinality keys first (good for group-by and filtering).

---

### `get_project_stats`

Overall project stats.

```json
{ "name": "get_project_stats", "arguments": {} }
```

**Returns**: project info + `{ total_users, total_logs, total_errors }`.

---

### `get_logs`

Fetch recent logs with optional filters.

```json
{
  "name": "get_logs",
  "arguments": {
    "limit": 100,
    "level": "error",
    "from": "2025-01-15",
    "to": "2025-01-22",
    "user_uuid": "optional-end-user-id"
  }
}
```

| Parameter | Type | Default | Notes |
|---|---|---|---|
| `limit` | number | 30 | Max 200 |
| `level` | string | — | `info` \| `warning` \| `error` \| `messages` |
| `from` | string | — | Date filter start `YYYY-MM-DD` |
| `to` | string | — | Date filter end `YYYY-MM-DD` (inclusive) |
| `user_uuid` | string | — | Filter to one End-User |

**Returns**: Array of log objects with `id`, `content`, `level`, `user_uuid`, `metadata`, `created_at`.

---

### `get_users`

List End-Users who have sent logs to this project. Use to find `user_uuid` values for `get_user_journey`.

```json
{
  "name": "get_users",
  "arguments": { "limit": 20, "offset": 0, "search": "optional" }
}
```

**Returns**: `{ users: [{ user_uuid, metadata, last_seen_at }], total }`.

---

### `get_dropoff_users`

**Use before `get_user_journey`** — returns the exact list of End-Users who reached step A of a funnel but did NOT reach step B within the attribution window. This makes drop-off investigation precise instead of guessing from the full user list.

```json
{
  "name": "get_dropoff_users",
  "arguments": {
    "step_a_value": "Paywall Viewed",
    "step_b_value": "Purchase Succeeded",
    "from": "2025-01-01",
    "to": "2025-01-31",
    "window_hours": 24,
    "limit": 20
  }
}
```

| Parameter | Type | Required | Notes |
|---|---|---|---|
| `step_a_value` | string | ✅ | Content substring for step A (case-insensitive LIKE) |
| `step_b_value` | string | ✅ | Content substring for step B |
| `from` | string | ✅ | Start date `YYYY-MM-DD` |
| `to` | string | ✅ | End date `YYYY-MM-DD` (inclusive) |
| `window_hours` | number | ❌ | Attribution window. Default 24h |
| `limit` | number | ❌ | Max users to return. Default 20, max 100 |

**Returns**:

```json
{
  "dropoff_users": [
    { "user_uuid": "abc-123", "first_step_a_at": "2025-01-15T10:23:00" }
  ],
  "total_step_a": 842,
  "total_dropoffs": 18,
  "dropoff_rate": 0.021
}
```

Feed each `user_uuid` from `dropoff_users` into `get_user_journey` to replay exactly what those users did before dropping off.

---

### `get_user_journey`

Full chronological log sequence for a specific End-User. Use to reconstruct what they did before an error or drop-off.

```json
{
  "name": "get_user_journey",
  "arguments": { "user_uuid": "abc-123", "limit": 100 }
}
```

**Returns**: Logs ordered oldest→newest for that End-User.

---

### `run_analysis`

Run a conversion funnel analysis. Optionally compare two time periods.

```json
{ "name": "run_analysis", "arguments": { "plan": { ... } } }
```

See **AnalysisPlan Schema** section below.

---

### `get_remote_config`

Read the current Remote Config flags for the project.

```json
{ "name": "get_remote_config", "arguments": {} }
```

**Returns**: A JSON object with all current flag key/value pairs.

---

### `set_remote_config_flag`

Set or delete a Remote Config flag. Use when analysis shows a feature needs to be toggled without a new release.

```json
{
  "name": "set_remote_config_flag",
  "arguments": {
    "key": "show_experimental_paywall",
    "value": "false"
  }
}
```

To **delete** a flag, omit `value` or pass `null`. Booleans (`"true"`/`"false"`) and numbers are auto-parsed.

**Returns**: `{ success: true, config: { ...all_current_flags } }`.

---

## AnalysisPlan Schema

An `AnalysisPlan` has a `blocks` array. Required: ≥ 2 `step` blocks + 1 `time-range` block.

### `step` block — a funnel step

```json
{
  "blockType": "step",
  "id": "s1",
  "displayName": "Paywall Viewed",
  "matcher": {
    "type": "content_contains",
    "value": "Paywall Viewed"
  }
}
```

`matcher.type` options:

| Type | Matches when... |
|---|---|
| `content_contains` | `content` field contains the value (case-insensitive LIKE) |
| `event_exact` | `metadata.event` equals value, OR `content` equals value |
| `content_regex` | `content` matches a JavaScript regex (applied in JS after SQL pre-filter) |

Optional per-step filters:

```json
"filters": [
  { "field": "level", "op": "equals", "value": "info" },
  { "field": "platform", "op": "equals", "value": "ios" }
]
```

---

### `time-range` block

```json
{
  "blockType": "time-range",
  "id": "tr1",
  "period1Start": "2025-01-01",
  "period1End": "2025-01-31",
  "period2Start": "2025-02-01",
  "period2End": "2025-02-28"
}
```

`period2Start`/`period2End` are optional. When provided, `run_analysis` returns a comparison with a `delta` object:

```json
{
  "delta": {
    "a_count": 120,
    "b_count": 18,
    "conversion_rate_abs": 0.04,
    "conversion_rate_rel": 0.25
  }
}
```

`conversion_rate_rel > 0` = improved. `< 0` = regression.

---

### `attribution` block (optional)

```json
{
  "blockType": "attribution",
  "id": "attr1",
  "linkBy": "user_id",
  "windowSeconds": 86400,
  "selection": "first-after"
}
```

Default: 24-hour window, first matching event after step A.

---

### `group-by` block (optional)

```json
{
  "blockType": "group-by",
  "id": "gb1",
  "dimensions": ["platform", "app_version"]
}
```

Use keys from `get_metadata_keys` where `isHighCardinality` is false.

---

### `filter` block (optional) — global filter on all logs

```json
{
  "blockType": "filter",
  "id": "f1",
  "conditions": [
    { "field": "platform", "op": "equals", "value": "ios" }
  ]
}
```

Filter operators: `equals`, `not_equals`, `exists`, `contains`.

---

### Full Example — Paywall → Purchase, broken down by platform

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
        "period1Start": "2025-01-01", "period1End": "2025-01-31"
      },
      {
        "blockType": "group-by", "id": "gb1",
        "dimensions": ["platform"]
      }
    ]
  }
}
```

---

## Available MCP Prompts

| Prompt | What it does |
|---|---|
| `analyze_errors` | Fetches errors, correlates with metadata, finds affected users, applies code fixes |
| `improve_conversion` | Discovers events → builds funnel → finds drop-off users → proposes and applies fixes |
| `post_release_check` | Compares error rate and conversion before vs. after a release to detect regressions |

These are built-in agent workflows. Invoke them by name in your MCP client.
