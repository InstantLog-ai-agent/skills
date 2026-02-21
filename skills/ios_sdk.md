---
name: instantlog_ios_sdk
description: |
  Use this skill when the Developer is working on an iOS (Swift) project and says things like:
  - "add InstantLog to my iOS project" / "set up logging in my iOS app"
  - "install the InstantLog iOS SDK" / "add the swift package"
  - "add logs to my SwiftUI app" / "instrument my iOS code with InstantLog"
  - "what methods does InstantLog have on iOS?" / "how do I use InstantLog in Swift?"
  - /instantlog-ios
  Teaches the agent how to install, configure, and use the official InstantLog iOS Swift Package.
---

# InstantLog iOS SDK — Agent Skill

## Overview

The InstantLog iOS SDK is an official Swift Package that wraps the InstantLog REST API. It provides:

- **Fire-and-forget logging** (`InstantLog.log`) — synchronous call, zero blocking
- **Async logging** (`InstantLog.logAsync`) — awaitable, throws typed errors
- **Thread safety** — actor-based, all network I/O off the main thread
- **Circuit breaker** — automatically stops sending if server returns HTTP 429
- **Internal queue** — AsyncStream-based, one consumer Task, no thread explosion

Zero external dependencies.

---

## Step 1 — Installation via Swift Package Manager

### Option A: Xcode UI

1. **File → Add Package Dependencies…**
2. Paste: `https://github.com/InstantLog-ai-agent/ios-logger`
3. Select version: `1.0.1` (or "Up to Next Major Version" from `1.0.1`)
4. Add to target.

### Option B: Package.swift dependency

```swift
// In Package.swift dependencies array:
.package(url: "https://github.com/InstantLog-ai-agent/ios-logger", from: "1.0.1"),

// In target dependencies array:
.product(name: "InstantLogiOS", package: "ios-logger"),
```

---

## Step 2 — Configuration (once at app launch)

Add this to `AppDelegate.application(_:didFinishLaunchingWithOptions:)` or the `@main` struct's `init()`:

```swift
import InstantLogiOS

InstantLog.configure(
    apiKey: "il_YOUR_API_KEY",          // from the InstantLog dashboard
    host: URL(string: "https://api.instantlog.io")!,
    defaultUserId: nil,                  // set after sign-in (see Step 4)
    enabled: true                        // set false to disable in Previews
)
```

### Disable in SwiftUI Previews (recommended)

```swift
InstantLog.configure(
    apiKey: "il_YOUR_API_KEY",
    host: URL(string: "https://api.instantlog.io")!,
    enabled: !ProcessInfo.processInfo.environment.keys
        .contains("XCODE_RUNNING_FOR_PREVIEWS")
)
```

### Full config parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `apiKey` | `String` | required | Project API key from dashboard |
| `host` | `URL` | required | InstantLog server base URL |
| `defaultUserId` | `String?` | `nil` | Auto-attached to every log |
| `enabled` | `Bool` | `true` | `false` = silent no-op for all calls |
| `timeout` | `TimeInterval` | `10` | Network timeout in seconds |

---

## Step 3 — Sending Logs

### Fire-and-forget (most common — use this everywhere)

```swift
// Basic
InstantLog.log("App launched")

// With level
InstantLog.log("Low storage warning", level: .warning)

// With user ID (overrides defaultUserId for this call)
InstantLog.log("User signed up", level: .info, userId: user.id)

// With metadata
InstantLog.log("Purchase completed", level: .info, metadata: [
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
    try await InstantLog.logAsync("Payment failed — critical", level: .error, metadata: [
        "error_code": "card_declined",
        "amount": 99
    ])
} catch InstantLogError.rateLimited {
    // Server banned this client — SDK is now suspended for this session
} catch InstantLogError.networkError(let e) {
    // No internet, timeout, etc.
} catch InstantLogError.serverError(let code) {
    // Server returned 4xx/5xx
} catch {
    // Other errors
}
```

---

## Step 4 — Setting the User ID

Set `defaultUserId` after sign-in so every subsequent log is tagged to that user:

```swift
// ✅ After successful sign-in
func userDidSignIn(user: User) {
    InstantLog.shared.config?.defaultUserId = user.id
    InstantLog.log("User signed in", level: .info, userId: user.id)
}

// ✅ After sign-out — clear the user
func userDidSignOut() {
    InstantLog.log("User signed out", userId: InstantLog.shared.config?.defaultUserId)
    InstantLog.shared.config?.defaultUserId = nil
}
```

> ⚠️ `InstantLog.shared.config` is `nil` until `configure()` is called. Always call `configure()` first.

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
InstantLog.log("App launched", metadata: ["cold_start": true])
InstantLog.log("App entered background")
InstantLog.log("App became active")
```

### Authentication

```swift
InstantLog.log("Sign up completed", level: .info, userId: newUser.id)
InstantLog.log("Sign in success", level: .info, userId: user.id)
InstantLog.log("Sign in failed", level: .error, metadata: ["reason": error.localizedDescription])
```

### Paywall / Purchases

```swift
InstantLog.log("Paywall shown", userId: user.id, metadata: ["trigger": "onboarding"])
InstantLog.log("Purchase initiated", userId: user.id, metadata: ["product": productId])
InstantLog.log("Purchase success", level: .info, userId: user.id, metadata: ["product": productId, "price": price])
InstantLog.log("Purchase failed", level: .error, userId: user.id, metadata: ["product": productId, "error": errorCode])
```

### Screen Views (SwiftUI)

```swift
.onAppear {
    InstantLog.log("Screen appeared: \(screenName)", userId: currentUser?.id)
}
```

### Errors

```swift
// In catch blocks
InstantLog.log("Network error in \(#function)", level: .error, metadata: [
    "error": error.localizedDescription,
    "url": url.absoluteString
])
```

---

## Step 7 — Standard Metadata Keys

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
- `InstantLog.log()` is synchronous and returns instantly (no await needed)
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

- [ ] `InstantLog.configure(...)` called once at app startup (before any `log()` calls)
- [ ] API key stored securely, not hardcoded in committed files
- [ ] `defaultUserId` set after sign-in, cleared after sign-out
- [ ] `enabled: false` set for Previews / unit test environment
- [ ] At least one log per step of the main conversion funnel
- [ ] `.error` level used for real failures, not `.warning`
- [ ] `app_version` and `platform: "ios"` included in metadata where relevant
- [ ] `logAsync` only used where delivery confirmation is explicitly required
