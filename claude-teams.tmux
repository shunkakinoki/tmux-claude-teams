#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$CURRENT_DIR/daemon/bin"
DAEMON_BIN="$BIN_DIR/daemon"
SOCKET="/tmp/claude-teams.sock"

# Build if needed
if [ ! -f "$DAEMON_BIN" ] || [ "$CURRENT_DIR/daemon/cmd/daemon/main.go" -nt "$DAEMON_BIN" ]; then
    mkdir -p "$BIN_DIR"
    (cd "$CURRENT_DIR/daemon" && go build -o "$DAEMON_BIN" ./cmd/daemon 2>/dev/null) || true
    (cd "$CURRENT_DIR/daemon" && go build -o "$BIN_DIR/send" ./cmd/send 2>/dev/null) || true
fi

# Start daemon if not already running
if [ -f "$DAEMON_BIN" ] && ! [ -S "$SOCKET" ]; then
    "$DAEMON_BIN" \
        --socket "$SOCKET" \
        --tmux "$(which tmux)" \
        --plugin-dir "$CURRENT_DIR" &
    disown
fi
