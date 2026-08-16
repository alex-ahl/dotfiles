#!/usr/bin/env bash
# Claude Code. Two ai windows, one per account config dir (ai-1->1, ai-2->2).
agent_windows() { echo "ai-1 ai-2"; }

# window -> "VAR=VAL " env prefix (trailing space), or empty for unknown windows.
_agent_env() { case "$1" in
    ai-1) printf 'CLAUDE_CONFIG_DIR=%s/.claude-account1 ' "$HOME" ;;
    ai-2) printf 'CLAUDE_CONFIG_DIR=%s/.claude-account2 ' "$HOME" ;;
  esac; }

# window, resume-slug ("" = cold).
agent_launch_cmd() {
  if [ -n "$2" ]; then printf '%sclaude "/resume %s"' "$(_agent_env "$1")" "$2"
  else                 printf '%sclaude'               "$(_agent_env "$1")"; fi
}
agent_continue_cmd() { printf '%sclaude --continue' "$(_agent_env "$1")"; }
agent_handoff_keys() { printf '/handoff %s' "$1"; }
agent_handoff_file() { printf '%s/%s.md' "$HANDOFF_DIR" "$1"; }

# pane_current_command -> 0 if it's a live Claude. Claude Code reports its
# version (e.g. "2.1.165") as the process command; a bare `node` also counts.
agent_is_cmd() { case "$1" in
    ""|zsh|-zsh|bash|-bash|sh|fish|tmux|login|nvim|vim) return 1 ;;
    claude|node) return 0 ;;
    [0-9]*.[0-9]*) return 0 ;;
    *) return 1 ;;
  esac; }
