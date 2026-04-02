#!/usr/bin/env bash
set -euo pipefail

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')

case "$TOOL_NAME" in
  Task|Agent|agent) ;;
  *) exit 0 ;;
esac

SOCKET="${CLAUDE_TEAMS_SOCKET:-/tmp/claude-teams.sock}"
SEND="${CLAUDE_TEAMS_SEND:-}"
TMUX_BIN="${CLAUDE_TEAMS_TMUX:-tmux}"

[ -S "$SOCKET" ] || exit 0
[ -n "$SEND" ] || exit 0

# Auto-detect which tmux pane Claude is running in.
# Walk up the process tree from this hook script to find a PID
# that owns a tmux pane.
detect_pane() {
    local pid=$$
    while [ "$pid" -gt 1 ] 2>/dev/null; do
        local pane_id
        pane_id=$("$TMUX_BIN" list-panes -a -F '#{pane_pid} #{pane_id}' 2>/dev/null | awk -v p="$pid" '$1 == p {print $2; exit}')
        if [ -n "$pane_id" ]; then
            echo "$pane_id"
            return
        fi
        pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
    done
}

PANE_ID=$(detect_pane)
[ -n "$PANE_ID" ] || exit 0

AGENT_ID=$(echo "$INPUT" | jq -r '.tool_use_id // empty')
DESCRIPTION=$(echo "$INPUT" | jq -r '(.tool_input.description // .tool_input.prompt // "subagent") | .[0:200]')

PAYLOAD=$(jq -n --arg id "$AGENT_ID" --arg pane "$PANE_ID" --arg desc "$DESCRIPTION" \
  '{event: "agent_start", agent_id: $id, pane_id: $pane, description: $desc}')

"$SEND" --socket "$SOCKET" "$PAYLOAD" 2>/dev/null || true
exit 0
