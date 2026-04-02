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
CLAUDE_BIN="$(tmux show-option -gqv @claude-teams-claude-bin)"
CLAUDE_BIN="${CLAUDE_BIN:-claude}"

# Launch claude in a new right pane as the leader
tmux split-window -h -p 50 "
  export PATH=\"$SHIM_DIR:\$PATH\"
  export CLAUDE_TEAMS_REAL_TMUX=\"$REAL_TMUX\"
  export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1
  $CLAUDE_BIN --teammate-mode auto
  exec \$SHELL
"

tmux select-layout main-vertical
