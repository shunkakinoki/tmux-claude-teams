#!/usr/bin/env bash
# Manual launcher - opens claude in a new pane.
# Not needed if you just run `claude` normally - hooks intercept automatically.
set -euo pipefail

REAL_TMUX="$(which tmux)"
CLAUDE_BIN="$($REAL_TMUX show-option -gqv @claude-teams-claude-bin 2>/dev/null || true)"
CLAUDE_BIN="${CLAUDE_BIN:-claude}"
CLAUDE_ABS="$(which "$CLAUDE_BIN" 2>/dev/null || echo "$CLAUDE_BIN")"

$REAL_TMUX split-window -h -p 50 "$CLAUDE_ABS"
$REAL_TMUX select-layout main-vertical
