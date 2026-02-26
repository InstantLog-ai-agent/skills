---
name: sensorcore_analytics_combinator
description: |
  Use this skill when the Developer asks a complex analytical question that requires MULTIPLE MCP tools.
  Examples:
  - "what's happening in my project?" / "give me a health check"
  - "why did conversion drop?" / "what changed after the release?"
  - "compare iOS vs Android" / "which country performs worst?"
  - "what predicts purchase?" / "what do paying users do differently?"
  - "prepare for release" / "post-release check"
  - "AB test results" / "which paywall variant wins?"
  - "where's the bottleneck in user flow?"
  - "when exactly did things break?"
  - any question that can't be answered by a single MCP tool call
  This skill teaches HOW to combine SensorCore MCP tools into multi-step analysis chains,
  how to cross-reference analytics results with the Developer's source code, and how to
  synthesize findings into actionable recommendations.
---

# SensorCore — Analytics Combinator Skill

## Core Principle — You Are a Senior Data Scientist & PM

Your role is NOT to fix bugs. Your role is to **prove the value of SensorCore** through deep analysis that no human dashboard can match.

You have THREE superpowers:

1. **MCP tools** — 21 server-side analytics tools that return compact aggregated results
2. **Source code access** — you can read the Developer's actual codebase, find where logs are placed, and understand code logic
3. **Business interpretation** — you connect technical anomalies to money

### Report First, Code Second

After running any analysis: **write an Executive Report FIRST**. Do NOT jump to code fixes.

The Developer's main value from SensorCore is the **insight**, not the code change. The report IS the product.

### The "Money" Connection

Raw numbers are useless. In every finding, answer: **"What does this mean for revenue?"**

| ❌ Don't say | ✅ Say instead |
|---|---|
| "Conversion dropped 5%" | "Conversion dropped 5% → losing ~$X/week due to iOS 17 localization bug. Fix returns revenue to baseline." |
| "p-value = 0.02" | "The drop is statistically confirmed (p=0.02), not random noise. This is a real problem costing money." |
| "3 error clusters found" | "3 error clusters affect 120 users. Top cluster blocks purchases → estimated $Y/month impact." |

### Self-Correction & Data Confidence

- If data is insufficient for a confident conclusion, **say so honestly**: "Not enough data for 100% confidence, but the current trend points to X."
- Before including any anomaly in the report, verify it through `get_user_journey` — minimum **3 real user paths**.
- Cross-check ML findings: if `get_bug_detective` says "iOS 17.4 only", verify with `get_segment_comparison` before reporting.

### Language Agnostic

Although iOS SDK (Swift) exists, the MCP system is universal. Any stack (Web, Android, Backend, Flutter) can send logs. During analysis, look for **logical errors** relevant to any platform, not just Swift patterns.

---

## Decision Tree — Which Tools for Which Question?

### Quick Start: One Question → One Tool

| Developer asks... | Call this |
|---|---|
| "What's happening? Any problems?" | `get_smart_alerts` |
| "What errors are there?" | `get_error_clusters` |
| "Show me events" | `get_event_names` |
| "How do users navigate the app?" | `get_user_flow` |
| "Will purchases grow next week?" | `get_forecast(event_name="Purchase Succeeded")` |
| "Read remote config flags" | `get_remote_config` |

### Deep Dive: Complex Questions → Tool Chains

| Developer asks... | Chain |
|---|---|
| "Why is conversion low?" | [Recipe 1: Conversion Investigation](#recipe-1--conversion-investigation) |
| "What broke after release?" | [Recipe 2: Post-Release Check](#recipe-2--post-release-check) |
| "iOS vs Android / DE vs US" | [Recipe 3: Segment Comparison](#recipe-3--segment-comparison) |
| "What predicts purchase?" | [Recipe 4: Conversion Predictors](#recipe-4--conversion-predictors) |
| "AB test: which variant wins?" | [Recipe 5: AB Test Read-out](#recipe-5--ab-test-read-out) |
| "On which devices does bug X happen?" | [Recipe 6: Bug Root Cause](#recipe-6--bug-root-cause) |
| "When exactly did things break?" | [Recipe 7: Change Point Detection](#recipe-7--change-point-detection) |
| "Full health check before release" | [Recipe 8: Pre-Release Health Check](#recipe-8--pre-release-health-check) |
| "What do our best users do?" | [Recipe 9: Behavioral Deep Dive](#recipe-9--behavioral-deep-dive) |
| "Check my logging" / "Audit my events" | [Recipe 10: Logging Audit](#recipe-10--logging-audit) |

---

## Recipes

### Recipe 1 — Conversion Investigation

**Trigger**: "Why aren't users converting?" / "Conversion is down"

```
Step 1: get_event_names()
        → Find the two funnel events (e.g. "Paywall Viewed" → "Purchase Succeeded")

Step 2: get_change_points(event_name="Purchase Succeeded", days=60, metric="count")
        → WHEN exactly did it drop? Anchors the investigation to a date.

Step 3: get_segment_comparison(segment_field="app_version", segment_a="2.0", segment_b="2.1")
        → Is the drop tied to a specific version? Try also: platform, country

Step 4: get_dropoff_users(step_a_value="Paywall Viewed", step_b_value="Purchase Succeeded",
                          from="change_point_date", to="today")
        → WHO exactly dropped off?

Step 5: get_user_journey(user_uuid="<from step 4>")  ← repeat for 2-3 users
        → WHAT did they do before dropping? Look for errors, loops, missing events.

Step 6: [SOURCE CODE] Search the codebase for the error or missing event found in step 5.
        → Fix the root cause or add missing logging.
```

**Synthesis pattern**: "Conversion dropped [when] because [root cause found via segment/journey]. [N] users were affected. The issue is in [file:line]. Fix: [specific change]."

---

### Recipe 2 — Post-Release Check

**Trigger**: "Did the release break anything?" / "Check after v2.1"

```
Step 1: get_smart_alerts(days=7)
        → Quick overview of current problems.

Step 2: get_error_clusters(days=3)
        → Any NEW error types that weren't there before?

Step 3: get_statistical_test(
          event_name="Purchase Succeeded",
          period1_start="7 days before release", period1_end="release date",
          period2_start="release date", period2_end="today")
        → Is the change statistically significant?

Step 4: get_forecast(event_name="Purchase Succeeded", history_days=60, forecast_days=7)
        → Are current values within the predicted range?

Step 5: IF errors spiked OR conversion dropped:
        get_bug_detective(error_content="<top new error>", dimensions="app_version,device,os_version")
        → Under what conditions does the new error occur?

Step 6: get_user_journey(user_uuid="<affected user>")
        → What exactly happens before the error?

Step 7: [SOURCE CODE] Find the regression and fix it.
        OR: set_remote_config_flag(key="feature_x_enabled", value="false")
        → Disable the broken feature immediately.
```

---

### Recipe 3 — Segment Comparison

**Trigger**: "iOS vs Android" / "Germany vs USA" / "Free vs Premium"

```
Step 1: get_metadata_keys()
        → Discover available segments and their values.

Step 2: get_segment_comparison(segment_field="platform", segment_a="ios", segment_b="android", days=30)
        → Statistical comparison across all metrics: events, errors, conversion, session length.

Step 3: IF one segment has significantly higher error_rate:
        get_bug_detective(dimensions="platform,os_version,device")
        → Drill into WHY.

Step 4: [SOURCE CODE] Search for platform-specific code paths.
        → Check if conditional logic differs between segments.
```

---

### Recipe 4 — Conversion Predictors

**Trigger**: "What predicts purchase?" / "What actions lead to conversion?"

```
Step 1: get_event_names(limit=50)
        → Get the full event list. Pick 8-15 promising features.

Step 2: get_association_rules(target_event="Purchase Succeeded", min_confidence=0.3, min_lift=1.2)
        → Which event combinations predict purchase?

Step 3: run_behavioral_analysis(
          cohort_a={did_event: "Purchase Succeeded"},
          cohort_b={did_event: "Paywall Viewed", not_event: "Purchase Succeeded"},
          features=[
            {type: "event_count", event: "tutorial_complete"},
            {type: "event_count", event: "feature_x_used"},
            {type: "event_presence", event: "referral_clicked"},
            ...top events from step 1
          ],
          method: "ml")
        → Random Forest importance ranking.

Step 4: [SOURCE CODE] Find where the top-importance features happen in the code.
        → Suggest making those features more prominent (e.g. nudge users toward tutorial_complete).
```

**Synthesis**: "tutorial_complete is the #1 predictor (importance 0.34). Users who complete it purchase at 3.2x rate. In the codebase, this happens at [file:line]. Recommendation: move the tutorial prompt earlier in the onboarding."

---

### Recipe 5 — AB Test Read-out

**Trigger**: "Which paywall variant wins?" / "AB test results"

```
Step 1: get_metadata_keys()
        → Confirm the AB test dimension (e.g. "paywall_variant").

Step 2: get_segment_comparison(segment_field="paywall_variant", segment_a="A", segment_b="B", days=14)
        → Statistical comparison with p-values and effect sizes.

Step 3: run_behavioral_analysis(
          cohort_a={metadata_filter: {paywall_variant: "A"}},
          cohort_b={metadata_filter: {paywall_variant: "B"}},
          features=[...key conversion events],
          method: "statistical")
        → Per-feature comparison showing WHERE the difference comes from.

Step 4: IF winner found:
        set_remote_config_flag(key="paywall_variant", value="B")
        → Roll everyone to the winner.

Step 5: [SOURCE CODE] Remove the losing variant code.
```

---

### Recipe 6 — Bug Root Cause

**Trigger**: "Why does error X happen?" / "On which devices?"

```
Step 1: get_error_clusters(days=7)
        → Identify the specific error cluster. Note its metadata_patterns.

Step 2: get_bug_detective(error_content="<error string>", dimensions="device,os_version,country,app_version")
        → Decision tree rules: "Occurs 85% on iOS 17.4 + country=FR, lift 4.2x"

Step 3: get_user_journey(user_uuid="<affected user from error cluster>")
        → What happened right before the error?

Step 4: [SOURCE CODE] Search for the error string in the codebase.
        → Find the exact throw/catch/log statement.
        → Check if there's a platform-specific condition that matches the decision tree output.
        → Fix the bug.
```

---

### Recipe 7 — Change Point Detection

**Trigger**: "When did things break?" / "When did conversion start dropping?"

```
Step 1: get_change_points(event_name="Purchase Succeeded", days=60, metric="count", sensitivity="medium")
        → Get exact dates of permanent changes.

Step 2: For each change point date:
        get_error_clusters(days=3)  ← filter mentally to the change date
        → Did new errors appear around that date?

Step 3: get_cohort_analysis(cohort_by="app_version", metric="errors")
        → Which app_version introduced the change?

Step 4: [SOURCE CODE] Check git log around the change point date.
        → Find the commit/release that caused the structural break.
```

---

### Recipe 8 — Pre-Release Health Check

**Trigger**: "About to release — is everything OK?" / "Pre-release check"

```
Step 1: get_smart_alerts(days=7)
        → Any existing problems to fix BEFORE releasing?

Step 2: get_forecast(event_name="error", history_days=30, forecast_days=7)
        → Error trend — are errors trending up?

Step 3: get_forecast(event_name="Purchase Succeeded", history_days=30, forecast_days=7)
        → Conversion trend — baseline for post-release comparison.

Step 4: get_cohort_analysis(cohort_by="app_version", metric="errors")
        → Error rate per version — is the current version stable?

Report: "Current state: [N errors trending up/down], [conversion at X/day].
After release, run Recipe 2 to compare."
```

---

### Recipe 9 — Behavioral Deep Dive

**Trigger**: "What do our best users do?" / "What separates paying users from free?"

```
Step 1: get_event_names(limit=50)
        → Build feature list from top events.

Step 2: run_behavioral_analysis(
          cohort_a={did_event: "Purchase Succeeded"},
          cohort_b={did_event: "*", not_event: "Purchase Succeeded"},
          features=[...all top events as event_count],
          method: "ml")
        → Feature importances — which behaviors matter most.

Step 3: get_user_flow(start_event="App Launched", max_steps=8)
        → How do users navigate? Where are bottlenecks?

Step 4: get_association_rules(target_event="Purchase Succeeded")
        → Which event sequences predict purchase?

Synthesis: Cross-reference user flow bottlenecks with behavioral analysis results.
If bottleneck is at a step that top buyers don't skip → that's the opportunity.
```

---

### Recipe 10 — Logging Audit

**Trigger**: Developer explicitly asks: "Check my logging" / "Audit my events" / "Am I logging everything I need?"

> Do NOT run this proactively. Only when the Developer asks.

```
Step 1: get_event_names(limit=100)
        → Full list of events the server has received.

Step 2: [SOURCE CODE] Scan the codebase for all SensorCore.log() / POST /api/logs calls.
        → Build a list of events the code SENDS.

Step 3: Compare:
        - Events in code but NOT in get_event_names → they're defined but never fire (dead code or unreachable path)
        - Funnel gaps: is there a "Paywall Viewed" but no "Purchase Initiated"? Missing step = blind spot.

Step 4: get_metadata_keys()
        → Check: is app_version and platform present? Are keys snake_case? Any high-cardinality junk?

Step 5: [SOURCE CODE] Verify metadata in log calls matches event_taxonomy conventions:
        - content: Title Case, verb-object, no variable data
        - metadata: flat, snake_case keys, correct types (bool not "true")
        - user_id: set after auth

Step 6: Report to Developer:
        - ✅ Covered: [list of well-instrumented events]
        - ⚠️ Missing: [funnel gaps or critical points without logging]
        - ❌ Issues: [naming inconsistencies, missing metadata, dead events]
        - Suggested additions with exact code (follow logging_integration + event_taxonomy skills)
```

---

## Source Code Integration

This is the agent's unique advantage. After every MCP analysis, apply these patterns:

### Pattern: Error → Code Fix

```
1. get_error_clusters → find error content string
2. Search the codebase for that exact string (grep/search)
3. Read the surrounding code: try/catch, API call, validation
4. Fix the root cause
5. Do NOT remove the existing error log — it confirms the fix in production
6. Add a recovery log near the fix
```

### Pattern: Missing Event → Add Logging

```
1. get_event_names → see what events exist
2. Compare with the Developer's conversion funnel — is there a gap?
   (e.g. "Paywall Viewed" exists but "Purchase Initiated" is missing)
3. Search codebase for the code that handles that step
4. Add the missing log call (follow event_taxonomy and logging_integration skills)
```

### Pattern: Metadata → Code Verification

```
1. get_metadata_keys → see what metadata is being sent
2. get_segment_comparison or get_bug_detective → find patterns
   (e.g. "error only on platform=ios AND os_version=17.4")
3. Search codebase for platform-specific code
4. Check if the condition matches the ML finding
5. Fix the conditional logic
```

### Pattern: Remote Config → Emergency Fix

```
1. Analysis finds a severe problem (broken paywall, crash loop)
2. get_remote_config → read current flags
3. Search codebase for where that flag is consumed (if it exists)
4. set_remote_config_flag → disable the broken feature
5. Fix the code properly for the next release
```

---

## Anti-Patterns — What NOT to Do

| ❌ Don't | ✅ Do Instead |
|---|---|
| Jump to code fixes after analysis | Write the Executive Report FIRST — the insight is the product |
| Report raw numbers ("p=0.02", "5% drop") | Connect to money: "losing $X/week because..." |
| Fetch 200 raw logs and count them manually | Use `get_error_clusters` or `get_event_names` — server does the counting |
| Build funnels by reading raw logs | Use `get_dropoff_users` — server calculates the funnel |
| Guess which users dropped off | Use `get_dropoff_users` — it gives you the exact list |
| Compare segments by eyeballing two `get_logs` calls | Use `get_segment_comparison` — it calculates p-values and effect sizes |
| Report anomalies without checking real user paths | Verify with `get_user_journey` (min 3 users) before including in report |
| Make confident claims on sparse data | Honestly state: "Not enough data for 100% confidence, but trend suggests X" |
| Ignore the source code after analysis | Locate the relevant code and explain the root cause |
| Set Remote Config flags without reading first | Always `get_remote_config` before `set_remote_config_flag` |
| Run ML tools without calling `get_event_names` first | Discovery tools give you the vocabulary for all other tools |

---

## Executive Report Template

After running any multi-step analysis, present findings as an **Executive Report**. This is the agent's main deliverable. Do NOT skip to code — the report IS the value.

Ignore brevity rules for this report. Be thorough.

```markdown
## Executive Summary

**What happened**: [1-2 sentences: what changed and when]
**Financial impact**: [Connect to money: revenue lost, users affected, projected cost if unfixed]
**Urgency**: [Critical / High / Medium / Low]
**Recommended action**: [1 sentence: what to do]

---

## Deep Dive — Evidence

### Data Sources
- `get_smart_alerts` / `get_error_clusters` → [what was found]
- `get_change_points` / `get_statistical_test` → [when it started, is it significant?]
- `get_segment_comparison` → [which segments are affected]
- `get_user_journey` (verified on 3+ real users) → [what users experience]

### Key Findings
1. [Finding with numbers AND business meaning]
2. [Finding with numbers AND business meaning]
3. [Finding with numbers AND business meaning]

### Data Confidence
- [If data is sufficient]: "High confidence — based on N users over M days, p-value < 0.05"
- [If data is sparse]: "Moderate confidence — limited data (N users), but trend is consistent across all segments"

---

## Root Cause

**Where**: [file:line — link to the code]
**What**: [What the code does wrong — explain the logic error]
**Why it matters**: [Connect back to the business impact]

---

## Action Plan

### Immediate (today)
1. [Emergency mitigation — e.g. Remote Config toggle]

### Short-term (this release)
2. [Code fix — specific change with expected impact]
3. [Additional logging to prevent blind spots]

### Monitoring (after fix)
4. Run `get_statistical_test` comparing 7 days before vs 7 days after fix
5. Run `get_forecast` to confirm return to baseline

### Expected Outcome
- [Projected improvement: "Conversion returns to X%, recovering ~$Y/week"]
```
