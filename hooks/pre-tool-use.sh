#!/usr/bin/env bash
set -euo pipefail

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')

# Match Agent tool (Claude Code's subagent spawner)
case "$TOOL_NAME" in
  Task|Agent|agent) ;;
  *) exit 0 ;;
esac

SOCKET="${CLAUDE_TEAMS_SOCKET:-/tmp/claude-teams.sock}"
SEND="${CLAUDE_TEAMS_SEND:-}"

[ -S "$SOCKET" ] || exit 0
[ -n "$SEND" ] || exit 0

AGENT_ID=$(echo "$INPUT" | jq -r '.tool_use_id // empty')
DESCRIPTION=$(echo "$INPUT" | jq -r '(.tool_input.description // .tool_input.prompt // "subagent") | .[0:200]')

PAYLOAD=$(jq -n --arg id "$AGENT_ID" --arg desc "$DESCRIPTION" \
  '{event: "agent_start", agent_id: $id, description: $desc}')

"$SEND" --socket "$SOCKET" "$PAYLOAD" 2>/dev/null || true
exit 0
