---
name: sensorcore_js_sdk
description: |
  Use this skill when the Developer is working on a JavaScript or TypeScript project and says things like:
  - "add SensorCore to my project" / "set up logging in my web app"
  - "install the SensorCore JS SDK" / "add the npm package"
  - "add logs to my Next.js / React / Node.js app" / "instrument my code with SensorCore"
  - "what methods does SensorCore have in JS?" / "how do I use SensorCore in TypeScript?"
  - "get remote config in JS" / "read remote config flags in TypeScript"
  - "how do I use Remote Config in my web app with SensorCore?"
  - /sensorcore-js
  Teaches the agent how to install, configure, and use the official SensorCore JavaScript/TypeScript SDK.
---

# SensorCore JS/TS SDK — Agent Skill

## Overview

The SensorCore JS/TS SDK is the official npm package that wraps the SensorCore REST API. It provides:

- **Fire-and-forget logging** (`SensorCore.log`) — synchronous call, zero blocking
- **Async logging** (`SensorCore.logAsync`) — awaitable, throws typed errors
- **Offline buffering** — failed logs saved to `localStorage` (browser) or `~/.sensorcore/pending.json` (Node.js), retried automatically
- **Circuit breaker** — timed exponential backoff on HTTP 429 (60s → 120s → 300s → 600s max)
- **Network recovery** — auto-flushes pending logs when connectivity returns (browser `online` event)
- **Remote Config** — typed accessors for feature flags set from the dashboard or by an AI agent

Zero external dependencies. Works in browser and Node.js 18+.

---

## Step 1 — Installation

```bash
npm install sensorcore
```

or with yarn / pnpm:

```bash
yarn add sensorcore
pnpm add sensorcore
```

---

## Step 2 — Configuration (once at app startup)

Add this to your entry point (e.g. `main.ts`, `index.ts`, `app.ts`, `_app.tsx`, `server.ts`):

```typescript
import SensorCore from 'sensorcore';

SensorCore.configure({
    apiKey: 'sc_YOUR_API_KEY',          // from the SensorCore dashboard
    defaultUserId: undefined,            // set after sign-in (see Step 4)
    enabled: true,                       // set false to disable in tests
});
```

### Disable in test environments (recommended)

```typescript
SensorCore.configure({
    apiKey: 'sc_YOUR_API_KEY',
    enabled: process.env.NODE_ENV !== 'test',
});
```

### Full config parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `apiKey` | `string` | required | Project API key from dashboard |
| `host` | `string` | `api.sensorcore.dev` | SensorCore server URL (rarely needed) |
| `defaultUserId` | `string?` | `undefined` | Auto-attached to every log |
| `enabled` | `boolean` | `true` | `false` = silent no-op for all calls |
| `timeout` | `number` | `10000` | Network timeout in **milliseconds** |
| `persistFailedLogs` | `boolean` | `true` | Save failed logs for auto-retry |
| `maxPendingLogs` | `number` | `500` | Max entries buffered offline |
| `pendingLogMaxAge` | `number` | `86400` | Drop buffered entries older than this (seconds) |

---

## Step 3 — Sending Logs

### Fire-and-forget (most common — use this everywhere)

```typescript
// Basic
SensorCore.log('App Launched');

// With level
SensorCore.log('Low Memory Warning', { level: 'warning' });

// With user ID (overrides defaultUserId for this call)
SensorCore.log('Sign Up Completed', { level: 'info', userId: user.id });

// With metadata
SensorCore.log('Purchase Succeeded', {
    level: 'info',
    userId: user.id,
    metadata: {
        product_id: 'premium_annual',
        price: 49.99,
        is_trial: false,
        app_version: APP_VERSION,
    },
});
```

### Async — when you need delivery confirmation

```typescript
import { SensorCoreError } from 'sensorcore';

// Use only when you explicitly need to know if the log was delivered
try {
    await SensorCore.logAsync('Purchase Failed', {
        level: 'error',
        metadata: { error_code: 'card_declined', amount: 99 },
    });
} catch (err) {
    if (err instanceof SensorCoreError) {
        switch (err.code) {
            case 'rate_limited':    break; // Circuit breaker active
            case 'network_error':   break; // No internet / timeout
            case 'server_error':    break; // Server returned 4xx/5xx
            case 'not_configured':  break; // configure() not called
            case 'encoding_failed': break; // Metadata serialization failed
        }
    }
}
```

---

## Step 4 — Setting the User ID

Set `defaultUserId` after sign-in so every subsequent log is tagged to that user.
Call `configure()` again — it safely reconfigures the SDK with the new user ID:

```typescript
// ✅ After successful sign-in — reconfigure with user ID
function userDidSignIn(user: User) {
    SensorCore.configure({
        apiKey: 'sc_YOUR_API_KEY',
        defaultUserId: user.id,
    });
    SensorCore.log('Sign In Completed', { userId: user.id });
}

// ✅ After sign-out — reconfigure without user ID
function userDidSignOut() {
    SensorCore.log('Sign Out');
    SensorCore.configure({
        apiKey: 'sc_YOUR_API_KEY',
        defaultUserId: undefined,
    });
}
```

Or, pass `userId` on every call without changing config:

```typescript
SensorCore.log('Did something', { userId: currentUser?.id });
```

---

## Step 5 — Log Levels

| Level | When to use |
|---|---|
| `'info'` | Normal user actions: page views, clicks, purchases, sign-ups (default) |
| `'warning'` | Recoverable issues: API retries, fallback paths, deprecation usage |
| `'error'` | Real failures: crashes, failed payments, auth errors → triggers error indicator in dashboard |
| `'messages'` | User-generated messages or chat events |

---

## Step 6 — Instrumentation Points to Add Automatically

When scanning a JS/TS codebase, add logs at these locations:

### App / Server Startup

```typescript
// Entry point (main.ts, server.ts, app.tsx, etc.)
SensorCore.log('App Launched', { metadata: { version: APP_VERSION, env: NODE_ENV } });
```

### Authentication

```typescript
SensorCore.log('Sign Up Completed', { userId: newUser.id });
SensorCore.log('Sign In Completed', { userId: user.id });
SensorCore.log('Sign In Failed', { level: 'error', metadata: { reason: error.message } });
SensorCore.log('Sign Out', { userId: user.id });
```

### Page / Screen Views (React, Next.js, Vue, etc.)

```typescript
// React — useEffect or route change handler
useEffect(() => {
    SensorCore.log('Screen Viewed', { userId: currentUser?.id, metadata: { screen: pathname } });
}, [pathname]);

// Next.js App Router — layout.tsx
SensorCore.log('Screen Viewed', { userId: session?.user?.id, metadata: { screen: '/dashboard' } });
```

### Paywall / Purchases

```typescript
SensorCore.log('Paywall Viewed', { userId: user.id, metadata: { trigger: 'onboarding' } });
SensorCore.log('Purchase Initiated', { userId: user.id, metadata: { product: productId } });
SensorCore.log('Purchase Succeeded', { userId: user.id, metadata: { product: productId, price } });
SensorCore.log('Purchase Failed', { level: 'error', userId: user.id, metadata: { product: productId, error: errorCode } });
```

### API Errors

```typescript
// In catch blocks, API error handlers, or global error middleware
SensorCore.log('API Request Failed', {
    level: 'error',
    metadata: {
        error: error.message,
        status: response?.status,
        endpoint,
    },
});
```

### Express / Fastify error middleware

```typescript
app.use((err, req, res, next) => {
    SensorCore.log('API Request Error', {
        level: 'error',
        metadata: { error: err.message, status: 500, endpoint: `${req.method} ${req.path}` },
    });
    res.status(500).json({ error: 'Internal Server Error' });
});
```

---

## Step 7 — Remote Config

Remote Config lets the SensorCore server (or an AI agent via MCP) control app behaviour **without a new release**.
Flags are set in the SensorCore dashboard or by an AI agent using `set_remote_config_flag`, and the app reads them at runtime.

### Fetching flags

```typescript
// Call once at startup (or on-demand, e.g. on route change)
const config = await SensorCore.remoteConfig();
```

`remoteConfig()` is **always safe**:

- Returns an empty config (no crash, no throw) if the SDK is not configured
- Returns an empty config if the server is unreachable or returns an error
- Returns an empty config if the response cannot be decoded

> ⚠️ Always provide a **default value** when reading flags — the server may return nothing on the first cold start.

### Typed accessors

| Method | Return type | Notes |
|---|---|---|
| `config.bool('key')` | `boolean \| undefined` | `undefined` if absent or wrong type |
| `config.string('key')` | `string \| undefined` | `undefined` if absent or wrong type |
| `config.number('key')` | `number \| undefined` | Any numeric value |
| `config.int('key')` | `number \| undefined` | Only exact integers |
| `config.get('key')` | `unknown` | Raw value |
| `config.raw` | `Record<string, unknown>` | Full decoded JSON dictionary |

### Examples

```typescript
const config = await SensorCore.remoteConfig();

// Feature flags
if (config.bool('show_new_onboarding') === true) {
    showNewOnboarding();
}

// Numeric tuning
const timeout = config.number('api_timeout_seconds') ?? 30;
const maxRetries = config.int('max_retries') ?? 3;

// A/B variants
const variant = config.string('paywall_variant') ?? 'control';
showPaywall(variant);

// Log the applied config for analytics
SensorCore.log('Config applied', {
    metadata: {
        paywall_variant: variant,
        new_onboarding: config.bool('show_new_onboarding') ?? false,
    },
});
```

### Recommended pattern — React

```typescript
function App() {
    const [features, setFeatures] = useState<SensorCoreRemoteConfig | null>(null);

    useEffect(() => {
        SensorCore.remoteConfig().then(setFeatures);
    }, []);

    if (features?.bool('maintenance_mode') === true) {
        return <MaintenancePage />;
    }

    return <MainContent />;
}
```

### Connection to AI agent

An AI agent can set flags using the MCP tool:

```text
set_remote_config_flag { key: "show_new_onboarding", value: "true" }
```

The app will read the updated flag on the next `remoteConfig()` call — **no deploy required**.

---

## Step 8 — Standard Metadata Keys

Always include these in every log for proper analytics filtering:

```typescript
const standardMeta = {
    app_version: process.env.APP_VERSION ?? '1.0.0',
    platform: typeof window !== 'undefined' ? 'web' : 'node',
    user_agent: typeof navigator !== 'undefined' ? navigator.userAgent : undefined,
};
```

---

## Important SDK Behaviours

### Fire-and-forget safety

- `SensorCore.log()` is synchronous and returns instantly (no await needed)
- It never throws — errors are swallowed
- Logs are queued internally and sent via background `setTimeout` consumer
- Safe to call from render functions, event handlers, middleware

### Queue

- Logs are buffered in an internal FIFO array (max 1,000 entries)
- A single `setTimeout(0)` consumer drains the queue sequentially
- If the queue is full, new logs are dropped (oldest preserved)

### Circuit breaker

- If the server returns HTTP 429, the SDK enters a **timed cooldown**
- Cooldown escalates: 60s → 120s → 300s → 600s (max)
- After cooldown expires, logging automatically resumes
- A successful request resets the cooldown entirely
- Unlike the iOS SDK (permanent silence), the JS SDK recovers automatically — suitable for long-running server processes

### Offline buffering

- Failed logs are saved to `localStorage` (browser) or `~/.sensorcore/pending.json` (Node.js)
- On browser `online` event or next `configure()` call, pending logs are flushed
- Each entry is retried max 3 times, then dropped
- Entries older than `pendingLogMaxAge` (default 24h) are pruned
- Set `persistFailedLogs: false` to disable entirely

### API Key Storage

- Never hardcode the API key directly in source files that go to version control
- Store in `.env` files, environment variables, or a secrets manager
- Use `process.env.SENSORCORE_API_KEY` or equivalent

---

## Agent Checklist

- [ ] `SensorCore.configure(...)` called once at app startup (before any `log()` calls)
- [ ] API key stored securely in env vars, not hardcoded in committed files
- [ ] `defaultUserId` set after sign-in, cleared after sign-out
- [ ] `enabled: false` set for test environment (`NODE_ENV === 'test'`)
- [ ] At least one log per step of the main conversion funnel
- [ ] `'error'` level used for real failures, not `'warning'`
- [ ] `app_version` and `platform` included in metadata where relevant
- [ ] `logAsync` only used where delivery confirmation is explicitly required
- [ ] `SensorCore.remoteConfig()` called at app startup to apply feature flags
- [ ] Default values provided for all Remote Config reads (never assume a flag exists)
- [ ] `npm install sensorcore` added to the project's `package.json`
