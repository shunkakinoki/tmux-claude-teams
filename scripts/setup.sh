#!/usr/bin/env bash
set -euo pipefail

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN_DIR="$PLUGIN_DIR/daemon/bin"
SEND_BIN="$BIN_DIR/send"
SOCKET="/tmp/claude-teams.sock"
SETTINGS="$HOME/.claude/settings.json"

echo "tmux-claude-teams setup"
echo "======================"
echo ""

# Build binaries
echo "Building binaries..."
mkdir -p "$BIN_DIR"
(cd "$PLUGIN_DIR/daemon" && go build -o "$BIN_DIR/daemon" ./cmd/daemon)
(cd "$PLUGIN_DIR/daemon" && go build -o "$BIN_DIR/send" ./cmd/send)
echo "  Built: $BIN_DIR/daemon"
echo "  Built: $BIN_DIR/send"

# Install hooks into ~/.claude/settings.json
echo ""
echo "Installing hooks into $SETTINGS..."

mkdir -p "$HOME/.claude"

if [ -f "$SETTINGS" ] && [ -s "$SETTINGS" ]; then
    EXISTING=$(cat "$SETTINGS")
else
    EXISTING="{}"
fi

# Check if hooks already installed
if echo "$EXISTING" | jq -e '.hooks.PreToolUse[]? | select(.matcher == "Agent") | .hooks[]? | select(.command | contains("claude-teams"))' >/dev/null 2>&1; then
    echo "  Hooks already installed, updating..."
    # Remove old hooks first
    EXISTING=$(echo "$EXISTING" | jq '
        .hooks.PreToolUse = [.hooks.PreToolUse[]? | select(.hooks[0]?.command | contains("claude-teams") | not)] |
        .hooks.PostToolUse = [.hooks.PostToolUse[]? | select(.hooks[0]?.command | contains("claude-teams") | not)]
    ')
fi

echo "$EXISTING" | jq \
    --arg socket "$SOCKET" \
    --arg send "$SEND_BIN" \
    --arg tmux "$(which tmux)" \
    --arg preh "$PLUGIN_DIR/hooks/pre-tool-use.sh" \
    --arg posth "$PLUGIN_DIR/hooks/post-tool-use.sh" '
  .hooks.PreToolUse = ((.hooks.PreToolUse // []) + [{
    "matcher": "Agent",
    "hooks": [{"type": "command", "command": "CLAUDE_TEAMS_SOCKET=\($socket) CLAUDE_TEAMS_SEND=\($send) CLAUDE_TEAMS_TMUX=\($tmux) \($preh)", "timeout": 5000}]
  }]) |
  .hooks.PostToolUse = ((.hooks.PostToolUse // []) + [{
    "matcher": "Agent",
    "hooks": [{"type": "command", "command": "CLAUDE_TEAMS_SOCKET=\($socket) CLAUDE_TEAMS_SEND=\($send) \($posth)", "timeout": 5000}]
  }])
' > "${SETTINGS}.tmp" && mv "${SETTINGS}.tmp" "$SETTINGS"

echo "  Hooks installed."

echo ""
echo "Done! The daemon starts automatically when tmux loads."
echo "Any Claude Code session in tmux will now show agent splits."
echo ""
echo "Make sure your tmux.conf has:"
echo "  run-shell $PLUGIN_DIR/claude-teams.tmux"
