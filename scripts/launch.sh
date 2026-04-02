#!/usr/bin/env bash
set -euo pipefail

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SHIM_DIR="$HOME/.tmux/claude-teams-shim"

# Resolve real tmux before shimming PATH
REAL_TMUX="$(which tmux)"

# Create shim directory with fake tmux binary
mkdir -p "$SHIM_DIR"
cat > "$SHIM_DIR/tmux" << SHIM
#!/usr/bin/env bash
set -euo pipefail
exec "$PLUGIN_DIR/scripts/tmux-shim.sh" "\$@"
SHIM
chmod +x "$SHIM_DIR/tmux"

# Read optional claude binary path from tmux option
CLAUDE_BIN="$($REAL_TMUX show-option -gqv @claude-teams-claude-bin)"
CLAUDE_BIN="${CLAUDE_BIN:-claude}"

# Get current tmux context
TMUX_VAL="$($REAL_TMUX display-message -p '#{socket_path},#{session_id},#{window_id}')"
TMUX_PANE_VAL="$($REAL_TMUX display-message -p '#{pane_id}')"

# Launch claude in a new right pane as the leader
$REAL_TMUX split-window -h -p 50 "\
  export PATH='$SHIM_DIR':\$PATH; \
  export CLAUDE_TEAMS_REAL_TMUX='$REAL_TMUX'; \
  export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1; \
  export TMUX='$TMUX_VAL'; \
  export TMUX_PANE='$TMUX_PANE_VAL'; \
  $CLAUDE_BIN; \
  exec \$SHELL"

$REAL_TMUX select-layout main-vertical
