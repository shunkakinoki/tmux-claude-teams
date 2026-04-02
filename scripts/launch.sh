#!/usr/bin/env bash
set -euo pipefail

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REAL_TMUX="$(which tmux)"
SOCKET="/tmp/claude-teams-$$.sock"
BIN_DIR="$PLUGIN_DIR/daemon/bin"
DAEMON_BIN="$BIN_DIR/daemon"
SEND_BIN="$BIN_DIR/send"

# Build daemon and send binaries if needed
if [ ! -f "$DAEMON_BIN" ] || [ "$PLUGIN_DIR/daemon/cmd/daemon/main.go" -nt "$DAEMON_BIN" ]; then
    mkdir -p "$BIN_DIR"
    (cd "$PLUGIN_DIR/daemon" && go build -o "$DAEMON_BIN" ./cmd/daemon)
    (cd "$PLUGIN_DIR/daemon" && go build -o "$SEND_BIN" ./cmd/send)
fi

# Get current pane context
CURRENT_PANE="$($REAL_TMUX display-message -p '#{pane_id}')"

# Read optional claude binary
CLAUDE_BIN="$($REAL_TMUX show-option -gqv @claude-teams-claude-bin)"
CLAUDE_BIN="${CLAUDE_BIN:-claude}"
CLAUDE_ABS="$(which "$CLAUDE_BIN" 2>/dev/null || echo "$CLAUDE_BIN")"

# Start daemon in background
"$DAEMON_BIN" \
    --socket "$SOCKET" \
    --tmux "$REAL_TMUX" \
    --pane "$CURRENT_PANE" \
    --plugin-dir "$PLUGIN_DIR" \
    --parent-pid $$ &
DAEMON_PID=$!

# Wait for socket
for _ in $(seq 1 30); do
    [ -S "$SOCKET" ] && break
    sleep 0.1
done

# Create wrapper that sets env and configures hooks via settings
WRAPPER="/tmp/claude-teams-wrapper-$$.sh"
cat > "$WRAPPER" << EOF
#!/usr/bin/env bash

# Write temporary hooks config for this session
HOOKS_SETTINGS="\$HOME/.claude/settings.local.json"
BACKUP=""
if [ -f "\$HOOKS_SETTINGS" ]; then
    BACKUP="\${HOOKS_SETTINGS}.claude-teams-backup"
    cp "\$HOOKS_SETTINGS" "\$BACKUP"
fi

# Merge hooks into settings.local.json
# If file exists, merge; otherwise create new
if [ -f "\$HOOKS_SETTINGS" ] && [ -s "\$HOOKS_SETTINGS" ]; then
    EXISTING=\$(cat "\$HOOKS_SETTINGS")
else
    EXISTING="{}"
fi

echo "\$EXISTING" | jq --arg socket "$SOCKET" --arg send "$SEND_BIN" --arg preh "$PLUGIN_DIR/hooks/pre-tool-use.sh" --arg posth "$PLUGIN_DIR/hooks/post-tool-use.sh" '
  .hooks.PreToolUse = ((.hooks.PreToolUse // []) + [{
    "matcher": "Agent",
    "hooks": [{"type": "command", "command": "CLAUDE_TEAMS_SOCKET=\($socket) CLAUDE_TEAMS_SEND=\($send) \($preh)", "timeout": 5000}]
  }]) |
  .hooks.PostToolUse = ((.hooks.PostToolUse // []) + [{
    "matcher": "Agent",
    "hooks": [{"type": "command", "command": "CLAUDE_TEAMS_SOCKET=\($socket) CLAUDE_TEAMS_SEND=\($send) \($posth)", "timeout": 5000}]
  }])
' > "\$HOOKS_SETTINGS"

cleanup() {
    if [ -n "\$BACKUP" ] && [ -f "\$BACKUP" ]; then
        mv "\$BACKUP" "\$HOOKS_SETTINGS"
    else
        rm -f "\$HOOKS_SETTINGS"
    fi
    kill $DAEMON_PID 2>/dev/null || true
    rm -f "$SOCKET"
    rm -f "$WRAPPER"
}
trap cleanup EXIT

export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1
"$CLAUDE_ABS" "\$@"
EOF
chmod +x "$WRAPPER"

# Launch claude wrapper in a new pane
$REAL_TMUX split-window -h -p 50 "$WRAPPER"
$REAL_TMUX select-layout main-vertical
