# tmux-claude-teams

Visualize Claude Code agent teams as native tmux pane splits. When Claude spawns subagents, each one appears as a pane stacked on the right. Works with any Claude Code session in tmux - no special launcher needed.

```
+------------------+--------+
|                  | Agent1 |
|                  +--------+
|  Claude Code     | Agent2 |
|                  +--------+
|                  | Agent3 |
+------------------+--------+
```

## Requirements

- tmux >= 3.0
- Go >= 1.23
- jq
- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code)

## Install

```bash
git clone https://github.com/shunkakinoki/tmux-claude-teams ~/ghq/github.com/shunkakinoki/tmux-claude-teams
```

Run setup (builds binaries, installs Claude Code hooks):

```bash
~/ghq/github.com/shunkakinoki/tmux-claude-teams/scripts/setup.sh
```

Add to `~/.tmux.conf` (or tmux.conf managed by home-manager):

```bash
run-shell ~/ghq/github.com/shunkakinoki/tmux-claude-teams/claude-teams.tmux
```

Reload tmux:

```bash
tmux source-file ~/.config/tmux/tmux.conf
```

## Usage

Just use `claude` normally in any tmux pane. When Claude spawns agents, they appear as splits.

The daemon starts automatically when tmux loads. Hooks in `~/.claude/settings.json` intercept Agent tool calls and notify the daemon to create/destroy panes.

## How it works

```
Claude Code --[hooks]--> hook scripts --[unix socket]--> Go daemon ---> tmux panes
```

1. Daemon starts on tmux init, listens on `/tmp/claude-teams.sock`
2. Claude Code `PreToolUse` hook fires when Agent tool is called
3. Hook script detects which tmux pane Claude is in (PID walk)
4. Daemon creates a split pane showing agent status
5. `PostToolUse` hook notifies completion, pane auto-closes after 3s

## Uninstall

Remove hooks from `~/.claude/settings.json` (entries containing "claude-teams") and remove the `run-shell` line from tmux.conf.

## License

MIT
