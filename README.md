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
- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code)
- [TPM](https://github.com/tmux-plugins/tpm)

## Install

Add to `~/.tmux.conf`:

```bash
set -g @plugin 'shunkakinoki/tmux-claude-teams'
```

Reload tmux, then press `prefix + I` to install.

## Usage

`prefix + T` - launches Claude Code with agent teams enabled in the current window.

Claude's subagents automatically spawn as new panes stacked on the right. The layout rebalances when agents exit.

## Options

```bash
# Change keybinding (default: T)
set -g @claude-teams-key 'C'

# Custom claude binary path
set -g @claude-teams-claude-bin '/path/to/claude'
```

## How it works

1. A tmux shim intercepts `split-window` calls from Claude Code
2. After each split, `select-layout main-vertical` rebalances panes
3. `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` enables Claude's multi-agent mode
4. The `after-kill-pane` hook rebalances when agents finish

## License

MIT
