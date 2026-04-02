# tmux-claude-teams

Visualize Claude Code agent teams as native tmux pane splits. When Claude spawns subagents, each one appears as a pane stacked on the right.

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

Clone the repo:

```bash
git clone https://github.com/shunkakinoki/tmux-claude-teams ~/.tmux/plugins/tmux-claude-teams
```

Add to `~/.tmux.conf`:

```bash
run-shell ~/.tmux/plugins/tmux-claude-teams/claude-teams.tmux
```

Add hooks to `~/.claude/settings.json` (adjust paths if you cloned elsewhere):

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Agent",
        "hooks": [
          {
            "type": "command",
            "command": "CLAUDE_TEAMS_SOCKET=/tmp/claude-teams.sock CLAUDE_TEAMS_SEND=~/.tmux/plugins/tmux-claude-teams/daemon/bin/send CLAUDE_TEAMS_TMUX=tmux ~/.tmux/plugins/tmux-claude-teams/hooks/pre-tool-use.sh",
            "timeout": 5000
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Agent",
        "hooks": [
          {
            "type": "command",
            "command": "CLAUDE_TEAMS_SOCKET=/tmp/claude-teams.sock CLAUDE_TEAMS_SEND=~/.tmux/plugins/tmux-claude-teams/daemon/bin/send ~/.tmux/plugins/tmux-claude-teams/hooks/post-tool-use.sh",
            "timeout": 5000
          }
        ]
      }
    ]
  }
}
```

Reload tmux:

```bash
tmux source-file ~/.tmux.conf
```

## Usage

Use `claude` in any tmux pane. Agents appear as splits automatically.

## How it works

```
Claude Code --[hooks]--> hook scripts --[unix socket]--> Go daemon ---> tmux panes
```

1. Daemon starts on tmux init, listens on `/tmp/claude-teams.sock`
2. `PreToolUse` hook fires when Agent tool is called
3. Hook script detects which tmux pane Claude is in (PID walk)
4. Daemon creates a split pane showing agent status
5. `PostToolUse` hook fires on completion, pane auto-closes after 3s

## License

MIT
