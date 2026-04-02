#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configurable keybinding (default: prefix + T)
KEY="$(tmux show-option -gqv @claude-teams-key)"
KEY="${KEY:-T}"

tmux bind-key "$KEY" run-shell "$CURRENT_DIR/scripts/launch.sh"

# Auto-rebalance layout when agent panes close
tmux set-hook -g after-kill-pane "select-layout main-vertical"
