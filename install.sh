#!/bin/bash
# InstantLog Skills Installer
#
# Run this from the ROOT of your project directory:
#   curl -fsSL https://raw.githubusercontent.com/InstantLog-ai-agent/skills/refs/heads/main/install.sh | bash
#   or: bash install.sh [target_dir]
#
# Re-running is safe — existing files are overwritten (updated), never duplicated.
# No sudo required — files are written only inside your project folder.
#
# Supports: Antigravity (.agents/skills/), Codex (.codex/skills/), custom path as $1

set -e

SKILLS_RAW="https://raw.githubusercontent.com/InstantLog-ai-agent/skills/refs/heads/main/skills"
SKILLS=(
  "ios_sdk.md"
  "logging_integration.md"
  "event_taxonomy.md"
  "mcp_data_access.md"
  "conversion_playbook.md"
)

# ── Sanity check: must be run from a project root ─────────────────────────────

# Warn if there's no recognizable project file nearby (but don't block)
if [ ! -f "package.json" ] && [ ! -f "*.xcodeproj" ] && [ ! -f "Cargo.toml" ] && \
   [ ! -f "pubspec.yaml" ] && [ ! -f "build.gradle" ] && [ ! -d ".git" ]; then
  echo "⚠️  Warning: no project root detected in the current directory."
  echo "   Run this script from the root folder of your project, for example:"
  echo "   cd ~/myproject && curl -fsSL ... | bash"
  echo "   Continuing anyway — installing into: $(pwd)"
  echo ""
fi

# ── Determine target directory ────────────────────────────────────────────────

if [ -n "$1" ]; then
  TARGET_DIR="$1"
elif [ -d ".agents" ]; then
  TARGET_DIR=".agents/skills"
elif [ -d ".agent" ]; then
  TARGET_DIR=".agent/skills"
elif [ -d ".codex" ]; then
  TARGET_DIR=".codex/skills"
else
  # Default: Antigravity / generic convention
  TARGET_DIR=".agents/skills"
fi

mkdir -p "$TARGET_DIR"

echo "📦 Installing InstantLog skills into: $(pwd)/$TARGET_DIR"
echo "   (Re-running this script will update skills to the latest version)"
echo ""

# ── Download skill files ──────────────────────────────────────────────────────

for skill in "${SKILLS[@]}"; do
  dest="$TARGET_DIR/instantlog_$skill"
  if command -v curl &>/dev/null; then
    curl -fsSL "$SKILLS_RAW/$skill" -o "$dest"
  elif command -v wget &>/dev/null; then
    wget -q "$SKILLS_RAW/$skill" -O "$dest"
  else
    echo "❌ Error: curl or wget is required."
    exit 1
  fi
  echo "  ✅ $skill"
done

echo ""
echo "✅ Done! Skills installed."
echo ""
echo "Next step — add InstantLog MCP to your agent config:"
echo ""
echo '  {
    "mcpServers": {
      "instantlog": {
        "url": "http://localhost:3000/api/mcp/sse",
        "headers": { "x-api-key": "il_YOUR_PROJECT_API_KEY" }
      }
    }
  }'
echo ""
echo "Replace the URL with https://api.instantlog.io/api/mcp/sse when using the hosted service."
echo "Get your API key from the InstantLog dashboard after creating a project."
