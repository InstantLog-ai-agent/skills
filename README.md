# InstantLog Skills

AI agent skill pack for [InstantLog](https://instantlog.io) — teaches your AI coding agent how to:

1. **Add logging** to your app with the right events, levels, and metadata
2. **Analyze production data** via the InstantLog MCP server
3. **Improve conversion** and fix errors based on real user data
4. **Toggle Remote Config** flags without shipping a new release

---

## Quick Install

```bash
curl -fsSL https://raw.githubusercontent.com/instantlog/instantlog-skills/main/install.sh | bash
```

The script auto-detects your agent's skill folder (`.agents/skills/`, `.agent/skills/`, `.codex/skills/`).

**Or manually** — copy the files from `skills/` into your project's agent skill directory.

---

## Skills

| File | Trigger | What it does |
|---|---|---|
| `logging_integration.md` | "Add InstantLog to my project" | Instruments your codebase with correct log calls |
| `event_taxonomy.md` | "What should I name my events?" | Standard naming conventions for analytics-ready logs |
| `mcp_data_access.md` | "Analyze my logs" / "Connect to InstantLog MCP" | Full MCP tool reference for querying data |
| `conversion_playbook.md` | "Why aren't users converting?" / "Check after release" | Step-by-step analysis → code fix → verify workflow |

---

## MCP Setup

After installing skills, add InstantLog to your agent's MCP config:

```json
{
  "mcpServers": {
    "instantlog": {
      "url": "http://localhost:3000/api/mcp/sse",
      "headers": { "x-api-key": "il_YOUR_PROJECT_API_KEY" }
    }
  }
}
```

> Replace URL with `https://api.instantlog.io/api/mcp/sse` for the hosted service.
> Get your API key from the InstantLog dashboard after creating a project.

---

## Slash Commands (example phrases)

These phrases trigger the right skill automatically:

- `/instantlog-setup` → "Add InstantLog logging to this project"
- `/instantlog-analyze` → "Analyze my InstantLog data and tell me what's happening"
- `/instantlog-errors` → "What errors are happening in production right now?"
- `/instantlog-conversion` → "Why aren't users converting? Check my funnel"
- `/instantlog-release-check` → "Did my last release break anything? Compare metrics"

---

## Requirements

- An [InstantLog](https://instantlog.io) account and project (free to start)
- An AI agent that supports MCP (Antigravity, Codex, Claude Desktop, etc.)
- Any app platform: iOS, Android, Web, or backend
