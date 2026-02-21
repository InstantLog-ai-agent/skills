---
name: instantlog_event_taxonomy
description: Defines a standard naming convention and taxonomy for InstantLog events. Use this skill when setting up logging in a new project to ensure that event names and metadata keys are consistent, discoverable, and useful for analytics from day one.
---

# InstantLog — Event Taxonomy Skill

## Why Taxonomy Matters

InstantLog's analytics engine filters events by the `content` field and groups by `metadata` keys. If event names are inconsistent ("paywall shown" vs "Paywall Viewed" vs "opened paywall"), the funnel analysis breaks and charts become meaningless.

**This skill defines the canonical naming rules** an agent must follow when instrumenting a new project.

---

## Naming Conventions

### `content` field — Event Name

- Use **Title Case with a verb-object pattern**: `"Verb Noun"` or `"Noun Action"`
- Keep it short and human-readable (≤ 60 chars recommended, hard max 200)
- Be specific enough to be unique within the funnel step it represents
- **Do NOT include variable data** in `content` — put it in `metadata` instead

| ✅ Good | ❌ Bad |
|---|---|
| `"Paywall Viewed"` | `"paywall"` |
| `"Purchase Succeeded"` | `"User purchased annual plan for $49.99"` |
| `"Sign Up Completed"` | `"signup"` |
| `"Onboarding Step Completed"` | `"step3"` |
| `"Feature Unlocked"` | `"feature_unlock_export_pdf_user_123"` |

---

## Standard Event Taxonomy

### 🚀 App Lifecycle

| Event `content` | `level` | Key Metadata |
|---|---|---|
| `"App Launched"` | `info` | `app_version`, `platform`, `is_first_launch` |
| `"App Backgrounded"` | `info` | `session_duration_seconds` |
| `"App Crashed"` | `error` | `error_message`, `stack_trace`, `app_version` |

### 👤 Authentication

| Event `content` | `level` | Key Metadata |
|---|---|---|
| `"Sign Up Started"` | `info` | `method` (email/apple/google) |
| `"Sign Up Completed"` | `info` | `method` |
| `"Sign Up Failed"` | `warning` | `method`, `error_code` |
| `"Sign In Completed"` | `info` | `method` |
| `"Sign Out"` | `info` | — |

### 💳 Monetization

| Event `content` | `level` | Key Metadata |
|---|---|---|
| `"Paywall Viewed"` | `info` | `screen`, `paywall_variant`, `plan_shown` |
| `"Purchase Initiated"` | `info` | `plan`, `price`, `currency` |
| `"Purchase Succeeded"` | `info` | `plan`, `price`, `currency`, `transaction_id` |
| `"Purchase Failed"` | `error` | `plan`, `error_code`, `error_message` |
| `"Purchase Restored"` | `info` | `plan` |
| `"Trial Started"` | `info` | `plan`, `trial_days` |
| `"Subscription Cancelled"` | `warning` | `plan`, `reason` |

### 🧭 Onboarding

| Event `content` | `level` | Key Metadata |
|---|---|---|
| `"Onboarding Started"` | `info` | — |
| `"Onboarding Step Completed"` | `info` | `step`, `step_name` |
| `"Onboarding Skipped"` | `warning` | `step` (last step reached) |
| `"Onboarding Completed"` | `info` | `total_steps` |

### ⚙️ Features

| Event `content` | `level` | Key Metadata |
|---|---|---|
| `"Feature Used"` | `info` | `feature_name`, `screen` |
| `"Feature Locked Shown"` | `info` | `feature_name` |
| `"Permission Requested"` | `info` | `permission` (camera/notifications/etc.) |
| `"Permission Granted"` | `info` | `permission` |
| `"Permission Denied"` | `warning` | `permission` |

### 🌐 Network & Errors

| Event `content` | `level` | Key Metadata |
|---|---|---|
| `"API Request Failed"` | `warning` | `endpoint`, `status_code`, `attempt` |
| `"API Request Error"` | `error` | `endpoint`, `status_code`, `error_message` |
| `"Unhandled Exception"` | `error` | `error_message`, `stack_trace`, `screen` |

---

## Standard Metadata Keys (Always Include)

These keys should be present in **every** log event:

```json
{
  "app_version": "2.1.0",
  "platform": "ios",
  "os_version": "17.4"
}
```

Add these when the context is known:

```json
{
  "screen": "Paywall",
  "is_premium": false,
  "locale": "en_US",
  "user_segment": "trial"
}
```

---

## Metadata Key Naming Rules

- **snake_case** for all keys (`app_version`, not `appVersion` or `AppVersion`)
- **Flat structure only** — no nested objects (the analytics engine doesn't support them)
- **Boolean values** as actual booleans (`true`/`false`), not strings (`"true"`)
- **Numbers** as numbers, not strings (`49.99`, not `"49.99"`)

---

## Agent Checklist

When instrumenting a project, verify:

- [ ] All event `content` strings are Title Case verb-object format
- [ ] Variable data is in `metadata`, not in `content`
- [ ] `app_version` and `platform` included in every log
- [ ] `user_id` populated for all events after authentication
- [ ] Conversion funnel has ≥ 2 events with consistent `content` names for analytics
- [ ] No duplicate event names that describe different things
- [ ] Error events use `level: "error"` (not `"warning"`)
