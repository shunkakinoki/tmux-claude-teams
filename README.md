# tmux-claude-teams

Spawn Claude Code agent teams as native tmux pane splits. Subagents stack vertically in a right column and auto-equalize as they spawn and exit.

```
+------------------+--------+
|                  | Agent1 |
|                  +--------+
|  Leader (you)    | Agent2 |
|                  +--------+
|                  | Agent3 |
+------------------+--------+
```

## Requirements

- tmux >= 3.0
- Go >= 1.23
- jq
- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code)
- [TPM](https://github.com/tmux-plugins/tpm) (optional)

## Install

### With TPM

Add to `~/.tmux.conf`:

```bash
set -g @plugin 'shunkakinoki/tmux-claude-teams'
```

Reload tmux, then press `prefix + I` to install.

### Manual

```bash
git clone https://github.com/shunkakinoki/tmux-claude-teams ~/.tmux/plugins/tmux-claude-teams
```

Add to `~/.tmux.conf`:

```bash
run-shell ~/.tmux/plugins/tmux-claude-teams/claude-teams.tmux
```

## Usage

`prefix + T` - launches Claude Code with agent teams in the current window.

When Claude spawns subagents via the Agent tool, each one appears as a pane stacked on the right. Panes auto-close 3 seconds after the agent completes.

## How it works

1. A Go daemon listens on a unix socket for agent lifecycle events
2. Claude Code hooks (`PreToolUse`/`PostToolUse`) notify the daemon when agents spawn/complete
3. The daemon creates/destroys tmux panes and rebalances with `main-vertical` layout
4. On exit, hooks config is restored and the daemon cleans up

## Options

```bash
# Change keybinding (default: T)
set -g @claude-teams-key 'C'

# Custom claude binary path
set -g @claude-teams-claude-bin '/path/to/claude'
```

## Architecture

```
Claude Code ──[hooks]──> hook scripts ──[unix socket]──> Go daemon ──> tmux panes
```

The Go daemon (auto-built on first run) manages pane lifecycle. Hook scripts are injected into `~/.claude/settings.local.json` for the session and restored on exit.

## License

MIT
