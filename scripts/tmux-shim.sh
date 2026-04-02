#!/usr/bin/env bash
set -euo pipefail

REAL="${CLAUDE_TEAMS_REAL_TMUX:-/usr/bin/tmux}"

case "${1:-}" in
  split-window)
    "$REAL" "$@"
    # Rebalance: leader stays left, agents stack vertically on the right
    "$REAL" select-layout main-vertical
    ;;
  kill-pane)
    "$REAL" "$@"
    "$REAL" select-layout main-vertical 2>/dev/null || true
    ;;
  *)
    "$REAL" "$@"
    ;;
esac
