# SensorCore Skills

AI agent skill pack for [SensorCore](https://sensorcore.dev) — teaches your AI coding agent how to:

1. **Add logging** to your app with the right events, levels, and metadata
2. **Analyze production data** via the SensorCore MCP server
3. **Improve conversion** and fix errors based on real user data
4. **Toggle Remote Config** flags without shipping a new release

---

## Quick Install

```bash
curl -fsSL https://raw.githubusercontent.com/sensorcore/skills/refs/heads/main/install.sh | bash
```

The script auto-detects your agent's skill folder (`.agents/skills/`, `.agent/skills/`, `.codex/skills/`).

**Or manually** — copy the files from `skills/` into your project's agent skill directory.

---

## Skills

| File | Trigger | What it does |
|---|---|---|
| `logging_integration.md` | "Add SensorCore to my project" | Instruments your codebase with correct log calls |
| `event_taxonomy.md` | "What should I name my events?" | Standard naming conventions for analytics-ready logs |
| `mcp_data_access.md` | "Analyze my logs" / "Connect to SensorCore MCP" | Complete reference of all 21 MCP tools (discovery, data, ML, config) |
| `analytics_combinator.md` | "Why did conversion drop?" / complex analytical questions | Multi-tool recipes: how to combine tools + cross-reference with source code |
| `conversion_playbook.md` | "Why aren't users converting?" / "Check after release" | Step-by-step playbook with ML tools: investigate → fix → verify |

---

## MCP Setup

After installing skills, add SensorCore to your agent's MCP config:

```json
{
  "mcpServers": {
    "sensorcore": {
      "url": "http://localhost:3000/api/mcp/sse",
      "headers": { "x-api-key": "sc_YOUR_PROJECT_API_KEY" }
    }
  }
}
```

> Replace URL with `https://api.sensorcore.dev/api/mcp/sse` for the hosted service.
> Get your API key from the SensorCore dashboard after creating a project.

---

## Slash Commands (example phrases)

These phrases trigger the right skill automatically:

- `/sensorcore-setup` → "Add SensorCore logging to this project"
- `/sensorcore-analyze` → "Analyze my SensorCore data and tell me what's happening"
- `/sensorcore-errors` → "What errors are happening in production right now?"
- `/sensorcore-conversion` → "Why aren't users converting? Check my funnel"
- `/sensorcore-release-check` → "Did my last release break anything? Compare metrics"

---

## Requirements

- An [SensorCore](https://sensorcore.dev) account and project (free to start)
- An AI agent that supports MCP (Antigravity, Codex, Claude Desktop, etc.)
- Any app platform: iOS, Android, Web, or backend
