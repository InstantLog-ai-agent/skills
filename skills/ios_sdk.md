---
name: sensorcore_ios_sdk
description: |
  Use this skill when the Developer is working on an iOS (Swift) project and says things like:
  - "add SensorCore to my iOS project" / "set up logging in my iOS app"
  - "install the SensorCore iOS SDK" / "add the swift package"
  - "add logs to my SwiftUI app" / "instrument my iOS code with SensorCore"
  - "what methods does SensorCore have on iOS?" / "how do I use SensorCore in Swift?"
  - "get remote config in iOS" / "read remote config flags in Swift"
  - "how do I use Remote Config in my iOS app with SensorCore?"
  - /sensorcore-ios
  Teaches the agent how to install, configure, and use the official SensorCore iOS Swift Package.
---

# SensorCore iOS SDK — Agent Skill

## Overview

The SensorCore iOS SDK is an official Swift Package that wraps the SensorCore REST API. It provides:

- **Fire-and-forget logging** (`SensorCore.log`) — synchronous call, zero blocking
- **Async logging** (`SensorCore.logAsync`) — awaitable, throws typed errors
- **Thread safety** — actor-based, all network I/O off the main thread
- **Circuit breaker** — automatically stops sending if server returns HTTP 429
- **Internal queue** — AsyncStream-based, one consumer Task, no thread explosion

Zero external dependencies.

---

## Step 1 — Installation via Swift Package Manager

### Option A: Xcode UI

1. **File → Add Package Dependencies…**
2. Paste: `https://github.com/sensorcore/ios`
3. Select version: `1.0.1` (or "Up to Next Major Version" from `1.0.1`)
4. Add to target.

### Option B: Package.swift dependency

```swift
// In Package.swift dependencies array:
.package(url: "https://github.com/sensorcore/ios", from: "1.0.1"),

// In target dependencies array:
.product(name: "SensorCoreiOS", package: "ios"),
```

---

## Step 2 — Configuration (once at app launch)

Add this to `AppDelegate.application(_:didFinishLaunchingWithOptions:)` or the `@main` struct's `init()`:

```swift
import SensorCoreiOS

SensorCore.configure(
    apiKey: "sc_YOUR_API_KEY",          // from the SensorCore dashboard
    defaultUserId: nil,                  // set after sign-in (see Step 4)
    enabled: true                        // set false to disable in Previews
)
```

### Disable in SwiftUI Previews (recommended)

```swift
SensorCore.configure(
    apiKey: "sc_YOUR_API_KEY",
    enabled: !ProcessInfo.processInfo.environment.keys
        .contains("XCODE_RUNNING_FOR_PREVIEWS")
)
```

### Full config parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `apiKey` | `String` | required | Project API key from dashboard |
| `host` | `URL` | `api.sensorcore.dev` | SensorCore server URL (rarely needed) |
| `defaultUserId` | `String?` | `nil` | Auto-attached to every log |
| `enabled` | `Bool` | `true` | `false` = silent no-op for all calls |
| `timeout` | `TimeInterval` | `10` | Network timeout in seconds |

---

## Step 3 — Sending Logs

### Fire-and-forget (most common — use this everywhere)

```swift
// Basic
SensorCore.log("App Launched")

// With level
SensorCore.log("Low Storage Warning", level: .warning)

// With user ID (overrides defaultUserId for this call)
SensorCore.log("Sign Up Completed", level: .info, userId: user.id)

// With metadata
SensorCore.log("Purchase Succeeded", level: .info, metadata: [
    "product_id": "premium_annual",
    "price": 49.99,
    "is_trial": false,
    "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
])
```

### Async — when you need delivery confirmation

```swift
// Use only when you explicitly need to know if the log was delivered
// (e.g., right before a critical state change or app termination)
do {
    try await SensorCore.logAsync("Purchase Failed", level: .error, metadata: [
        "error_code": "card_declined",
        "amount": 99
    ])
} catch SensorCoreError.rateLimited {
    // Server banned this client — SDK is now suspended for this session
} catch SensorCoreError.networkError(let e) {
    // No internet, timeout, etc.
} catch SensorCoreError.serverError(let code) {
    // Server returned 4xx/5xx
} catch {
    // Other errors
}
```

---

## Step 4 — Setting the User ID

Set `defaultUserId` after sign-in so every subsequent log is tagged to that user.
Call `configure()` again — it safely reconfigures the SDK with the new user ID:

```swift
// ✅ After successful sign-in — reconfigure with user ID
func userDidSignIn(user: User) {
    SensorCore.configure(
        apiKey: "sc_YOUR_API_KEY",
        defaultUserId: user.id
    )
    SensorCore.log("Sign In Completed", level: .info, userId: user.id)
}

// ✅ After sign-out — reconfigure without user ID
func userDidSignOut() {
    SensorCore.log("Sign Out")
    SensorCore.configure(apiKey: "sc_YOUR_API_KEY")
}
```

> ⚠️ `configure()` is safe to call multiple times — each call replaces the previous configuration.

---

## Step 5 — Log Levels

| Level | When to use |
|---|---|
| `.info` | Normal user actions: screen views, taps, purchases, sign-ups (default) |
| `.warning` | Recoverable issues: API retries, fallback paths, deprecated usage |
| `.error` | Real failures: crashes, failed payments, auth errors → triggers error indicator in dashboard |
| `.messages` | User-generated messages or chat events |

---

## Step 6 — Instrumentation Points to Add Automatically

When scanning an iOS codebase, add logs at these locations:

### App Lifecycle

```swift
// AppDelegate / @main
SensorCore.log("App Launched", metadata: ["cold_start": true])
SensorCore.log("App Backgrounded")
SensorCore.log("App Became Active")
```

### Authentication

```swift
SensorCore.log("Sign Up Completed", level: .info, userId: newUser.id)
SensorCore.log("Sign In Completed", level: .info, userId: user.id)
SensorCore.log("Sign In Failed", level: .error, metadata: ["reason": error.localizedDescription])
```

### Paywall / Purchases

```swift
SensorCore.log("Paywall Viewed", userId: user.id, metadata: ["trigger": "onboarding"])
SensorCore.log("Purchase Initiated", userId: user.id, metadata: ["product": productId])
SensorCore.log("Purchase Succeeded", level: .info, userId: user.id, metadata: ["product": productId, "price": price])
SensorCore.log("Purchase Failed", level: .error, userId: user.id, metadata: ["product": productId, "error": errorCode])
```

### Screen Views (SwiftUI)

```swift
.onAppear {
    SensorCore.log("Screen Viewed", userId: currentUser?.id, metadata: ["screen": screenName])
}
```

### Errors

```swift
// In catch blocks
SensorCore.log("API Request Failed", level: .error, metadata: [
    "error": error.localizedDescription,
    "endpoint": url.absoluteString
])
```

---

## Step 8 — Remote Config

Remote Config lets the SensorCore server (or an AI agent via MCP) control app behaviour **without a new release**.
Flags are set in the SensorCore dashboard or by an AI agent using `set_remote_config_flag`, and the iOS app reads them at runtime.

### Fetching flags

```swift
// Call once at startup (or on-demand, e.g. on app foreground)
let config = await SensorCore.remoteConfig()
```

`remoteConfig()` is **always safe**:

- Returns an empty config (no crash, no throw) if the SDK is not configured
- Returns an empty config if the server is unreachable or returns an error
- Returns an empty config if the response cannot be decoded

> ⚠️ Always provide a **default value** when reading flags — the server may return nothing on the first cold start.

### Typed accessors

| Method | Return type | Notes |
|---|---|---|
| `config.bool(for: "key")` | `Bool?` | `nil` if absent or wrong type |
| `config.string(for: "key")` | `String?` | `nil` if absent or wrong type |
| `config.double(for: "key")` | `Double?` | Also accepts Int from server |
| `config.int(for: "key")` | `Int?` | Only exact integers |
| `config["key"]` | `Any?` | Raw subscript — cast it yourself |
| `config.raw` | `[String: Any]` | Full decoded JSON dictionary |

### Examples

```swift
let config = await SensorCore.remoteConfig()

// Feature flags
if config.bool(for: "show_new_onboarding") == true {
    showNewOnboarding()
}

// Numeric tuning
let timeout = config.double(for: "api_timeout_seconds") ?? 30.0
let maxRetries = config.int(for: "max_retries") ?? 3

// A/B variants
let variant = config.string(for: "paywall_variant") ?? "control"
showPaywall(variant: variant)

// Log the applied config for analytics
SensorCore.log("Config applied", metadata: [
    "paywall_variant": variant,
    "new_onboarding": config.bool(for: "show_new_onboarding") ?? false
])
```

### Recommended pattern — fetch at app startup

```swift
@main
struct MyApp: App {
    init() {
        SensorCore.configure(apiKey: "sc_YOUR_KEY")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    // Apply config as soon as the root view appears
                    let config = await SensorCore.remoteConfig()
                    AppFeatures.apply(config)
                }
        }
    }
}
```

### Connection to AI agent

An AI agent can set flags using the MCP tool:

```text
set_remote_config_flag { key: "show_new_onboarding", value: "true" }
```

The iOS app will read the updated flag on the next `remoteConfig()` call — **no app release required**.

---

## Step 9 — Standard Metadata Keys

Always include these in every log for proper analytics filtering:

```swift
let standardMeta: [String: Any] = [
    "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "",
    "platform": "ios",
    "os_version": UIDevice.current.systemVersion,
    "device_model": UIDevice.current.model
]
```

---

## Important SDK Behaviours

### Thread Safety

- All logs are dispatched off the main thread automatically
- `SensorCore.log()` is synchronous and returns instantly (no await needed)
- Safe to call from `@MainActor`, SwiftUI views, button actions

### Queue

- Logs are buffered in an internal `AsyncStream` queue (max 1,000 entries)
- A single background Task drains the queue sequentially
- If overwhelmed, oldest logs are preserved, new ones are dropped

### Circuit Breaker

- If server returns HTTP 429 (rate limit / ban), SDK **permanently stops** sending for the app session
- No further network requests until the app is relaunched
- Prevents an infinite log loop from hammering the server

### Config / API Key Storage

- Never hardcode the API key directly in source files that go to version control
- Store in `Info.plist` (after adding to `.gitignore` for secrets), `xcconfig` file, or environment variables

---

## Agent Checklist

- [ ] `SensorCore.configure(...)` called once at app startup (before any `log()` calls)
- [ ] API key stored securely, not hardcoded in committed files
- [ ] `defaultUserId` set after sign-in, cleared after sign-out
- [ ] `enabled: false` set for Previews / unit test environment
- [ ] At least one log per step of the main conversion funnel
- [ ] `.error` level used for real failures, not `.warning`
- [ ] `app_version` and `platform: "ios"` included in metadata where relevant
- [ ] `logAsync` only used where delivery confirmation is explicitly required
- [ ] `SensorCore.remoteConfig()` called at app startup to apply feature flags
- [ ] Default values provided for all Remote Config reads (never assume a flag exists)
