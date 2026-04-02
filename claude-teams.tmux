#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

KEY="$(tmux show-option -gqv @claude-teams-key)"
KEY="${KEY:-T}"

tmux bind-key "$KEY" run-shell "$CURRENT_DIR/scripts/launch.sh"
