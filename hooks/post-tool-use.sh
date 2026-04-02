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

[ -S "$SOCKET" ] || exit 0
[ -n "$SEND" ] || exit 0

AGENT_ID=$(echo "$INPUT" | jq -r '.tool_use_id // empty')
RESULT=$(echo "$INPUT" | jq -r '(.tool_result // "completed") | tostring | .[0:500]')

PAYLOAD=$(jq -n --arg id "$AGENT_ID" --arg result "$RESULT" \
  '{event: "agent_stop", agent_id: $id, result: $result}')

"$SEND" --socket "$SOCKET" "$PAYLOAD" 2>/dev/null || true
exit 0
