---
name: sensorcore_logging_integration
description: |
  Use this skill when the Developer says things like:
  - "add SensorCore to my project" / "set up logging with SensorCore"
  - "add logs to my app" / "instrument my code with SensorCore"
  - "where should I put logs?" / "help me add analytics logging"
  - /sensorcore-setup
  Teaches the agent how to instrument any app (iOS, Android, Web) with SensorCore
  log calls: setup, API key storage, log levels, metadata design, and platform examples.
---

# SensorCore — Logging Integration Skill

## Overview

SensorCore collects logs from any app via a single REST endpoint. There is no SDK to install — just HTTP. Your job as an agent is to:

1. Understand the Developer's codebase structure and identify **key instrumentation points**.
2. Insert `POST /api/logs` calls at those points with the correct payload.
3. Ensure that every log carries the right `level`, meaningful `content`, a `user_id`, and well-structured `metadata`.

---

## Terminology Reminder

| Term | Meaning |
|---|---|
| **Developer** | The person using SensorCore — they own the account and project. |
| **End-User** | The person using the Developer's app. They appear in logs as `user_id`. |

Never confuse these two. The Developer's API Key is secret and must never be shipped in client-side code that End-Users can read.

---

## Step 1 — Setup (Developer does this once)

1. Create an account at **sensorcore.dev**
2. Create a **Project** → copy the **API Key** (format: `sc_...`)
3. Store the API Key as an environment variable or in a build config:
   - iOS: `Info.plist` / `xcconfig` / environment
   - Android: `local.properties` / `BuildConfig`
   - Web/Node: `.env` file (`SENSORCORE_API_KEY=sc_...`)

**Base URL**: `https://api.sensorcore.dev` (or `http://localhost:3000` for local dev)

---

## Step 2 — The Log Ingestion Endpoint

```
POST /api/logs
Header: x-api-key: <PROJECT_API_KEY>
Content-Type: application/json
```

### Request Body

```json
{
  "content": "User tapped Purchase button",
  "level": "info",
  "user_id": "user-uuid-or-device-id",
  "metadata": {
    "screen": "Paywall",
    "plan": "annual",
    "app_version": "2.1.0",
    "os": "iOS 17.2"
  }
}
```

| Field | Required | Type | Notes |
|---|---|---|---|
| `content` | ✅ | string (max 200 chars) | Human-readable event description |
| `level` | ❌ | `info` \| `warning` \| `error` \| `messages` | Default: `info` |
| `user_id` | ❌ | string | End-User identifier (device ID, auth UID, etc.) |
| `metadata` | ❌ | flat JSON object | Arbitrary key/value for filtering & analytics |

### Response

```json
{ "status": "ok", "id": 12345 }
```

---

## Step 3 — Log Level Strategy

| Level | When to use |
|---|---|
| `info` | Normal user actions: screen views, taps, purchases, sign-ups |
| `warning` | Recoverable issues: API retries, unexpected state, degraded UX |
| `error` | Crashes, unhandled exceptions, failed payments, auth failures |
| `messages` | User-generated content or chat events |

> ⚠️ `error` logs automatically set the **error indicator** on the project dashboard. They are designed to catch real production problems.

---

## Step 4 — Where to Add Logs (Instrumentation Strategy)

When scanning a codebase, look for and instrument these types of locations:

### Lifecycle Events

- App launch / first open
- User sign-up / sign-in / sign-out
- Session start / session end

### Conversion Funnel Events

- Paywall / pricing screen viewed
- Purchase initiated
- Purchase succeeded / failed
- Trial started
- Subscription cancelled

### Feature Usage

- Key feature activated (e.g. "Export PDF tapped")
- Onboarding step completed
- Settings changed

### Errors & Warnings

- Network request failures (include HTTP status code in metadata)
- Parsing or decode errors
- Permission denied (camera, notifications, etc.)

---

## Step 5 — Metadata Design

Keep metadata **flat** (no nested objects). Use consistent key names across all logs so analytics filters work correctly.

### Recommended Standard Keys

```json
{
  "app_version": "2.1.0",
  "os": "iOS 17.4",
  "os_version": "17.4",
  "platform": "ios",
  "screen": "Paywall",
  "plan": "annual",
  "locale": "en_US",
  "is_premium": true
}
```

> Always include `app_version` and `platform` — these are the most commonly needed filter dimensions for analytics.

---

## Platform Examples

### iOS (Swift)

```swift
func logEvent(_ content: String, level: String = "info", userId: String? = nil, metadata: [String: Any]? = nil) {
    guard let url = URL(string: "https://api.sensorcore.dev/api/logs") else { return }
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("sc_YOUR_API_KEY", forHTTPHeaderField: "x-api-key")

    var body: [String: Any] = ["content": content, "level": level]
    if let uid = userId { body["user_id"] = uid }
    if let meta = metadata { body["metadata"] = meta }

    request.httpBody = try? JSONSerialization.data(withJSONObject: body)
    URLSession.shared.dataTask(with: request).resume()
}

// Usage:
logEvent("Paywall viewed", userId: currentUser.id, metadata: [
    "plan": "annual",
    "app_version": Bundle.main.shortVersion,
    "screen": "Paywall"
])
```

### Android (Kotlin)

```kotlin
fun logEvent(content: String, level: String = "info", userId: String? = null, metadata: Map<String, Any>? = null) {
    Thread {
        val url = URL("https://api.sensorcore.dev/api/logs")
        val conn = url.openConnection() as HttpURLConnection
        conn.requestMethod = "POST"
        conn.setRequestProperty("Content-Type", "application/json")
        conn.setRequestProperty("x-api-key", "sc_YOUR_API_KEY")
        conn.doOutput = true

        val body = mutableMapOf<String, Any>("content" to content, "level" to level)
        userId?.let { body["user_id"] = it }
        metadata?.let { body["metadata"] = it }

        conn.outputStream.write(JSONObject(body).toString().toByteArray())
        conn.connect()
        conn.inputStream.close()
    }.start()
}
```

### JavaScript / TypeScript

```typescript
async function logEvent(
  content: string,
  level: 'info' | 'warning' | 'error' | 'messages' = 'info',
  userId?: string,
  metadata?: Record<string, unknown>
) {
  await fetch('https://api.sensorcore.dev/api/logs', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-api-key': process.env.SENSORCORE_API_KEY!,
    },
    body: JSON.stringify({ content, level, user_id: userId, metadata }),
  });
}
```

---

## Agent Checklist Before Committing Changes

- [ ] API Key is stored as a secret/env var, not hardcoded in source
- [ ] Every log has a meaningful `content` string (≤ 200 chars)
- [ ] `user_id` is populated wherever the current End-User is known
- [ ] `app_version` and `platform` are always included in metadata
- [ ] Errors are logged at `level: "error"` (not `"warning"`)
- [ ] Log calls are fire-and-forget (non-blocking, no await where not needed)
- [ ] At least one log covers each step of the main conversion funnel
