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

# Resolve claude to absolute path before shimming PATH
CLAUDE_ABS="$(which "$CLAUDE_BIN" 2>/dev/null || echo "$CLAUDE_BIN")"

# Create a wrapper script that sets env and runs claude
WRAPPER="$SHIM_DIR/claude-teams-wrapper.sh"
cat > "$WRAPPER" << EOF
#!/usr/bin/env bash
export PATH="$SHIM_DIR:\$PATH"
export CLAUDE_TEAMS_REAL_TMUX="$REAL_TMUX"
export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1
exec "$CLAUDE_ABS" --agent-teams "\$@"
EOF
chmod +x "$WRAPPER"

# Launch wrapper in a new right pane
$REAL_TMUX split-window -h -p 50 "$WRAPPER"
$REAL_TMUX select-layout main-vertical
