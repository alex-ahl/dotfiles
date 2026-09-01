#!/usr/bin/env bash
# Claude Code. Two ai windows, one per account config dir (ai-1->1, ai-2->2).
agent_windows() { echo "ai-1 ai-2"; }

# window -> "VAR=VAL " env prefix (trailing space), or empty for unknown windows.
# $HOME stays unexpanded: it must resolve to the sandvault home, not this one.
_agent_env() { case "$1" in
    ai-1) printf 'CLAUDE_CONFIG_DIR=\\$HOME/.claude-account1 ' ;;
    ai-2) printf 'CLAUDE_CONFIG_DIR=\\$HOME/.claude-account2 ' ;;
  esac; }

# Resolved here, not left as \$HOME: srt's -s is plain argv, so no shell expands
# it. -P so the path is the physical one both accounts see.
_agent_srt_settings="$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd -P)/srt-settings.json"

# Sandbox invocation, up to and including `zsh -lc`. Default is sandvault alone.
# WSG_EGRESS=1 adds srt's domain allowlist (scripts/lib/srt-settings.json), which
# needs `sv -x`: seatbelt does not nest and srt is itself sandbox-exec, so this
# gives one seatbelt each — sandvault the separate UID, srt the policy.
# srt must wrap zsh, never `srt -c '<string>'`: that runs bash, which skips
# .zshenv, so the gh token router's function would not exist (see lib/gh-token.sh).
# ${PWD:A}, not $PWD: .zshrc re-enters the share through ~/git so the prompt can
# shorten it, which leaves $PWD under a home the other account cannot traverse
# (0750). :A resolves it back — a no-op when the pane never normalised it.
_agent_sandbox() {
  if [ -n "${WSG_EGRESS:-}" ]; then
    printf 'sv -x shell "${PWD:A}" -- srt -s %s zsh -lc' "$_agent_srt_settings"
  else
    printf 'sv shell "${PWD:A}" -- zsh -lc'
  fi
}

# window, resume-slug ("" = cold).
# Sandboxed via `sv shell`, not `sv claude`: sv launches with env -i, so the
# per-account CLAUDE_CONFIG_DIR only survives if set inside the sandbox shell.
# $PWD is the pane's worktree, expanded here; $HOME is expanded inside.
agent_launch_cmd() {
  # /handoff-resume, not /resume — the latter is Claude's built-in session picker.
  if [ -n "$2" ]; then printf '%s "%sclaude \\"/handoff-resume %s\\""' "$(_agent_sandbox)" "$(_agent_env "$1")" "$2"
  else                 printf '%s "%sclaude"' "$(_agent_sandbox)" "$(_agent_env "$1")"; fi
}
agent_continue_cmd() { printf '%s "%sclaude --continue"' "$(_agent_sandbox)" "$(_agent_env "$1")"; }
agent_handoff_keys() { printf '/handoff %s' "$1"; }
agent_handoff_file() { printf '%s/%s.md' "$HANDOFF_DIR" "$1"; }

# Process name as ps reports it, for the pane-tree walk in agent-badge.sh.
agent_proc_name() { echo claude; }

# pane_current_command -> 0 if it's a live Claude. Claude Code reports its
# version (e.g. "2.1.165") as the process command; a bare `node` also counts.
# Under sandvault the pane reports `sudo` (sv runs the agent through it).
agent_is_cmd() { case "$1" in
    ""|zsh|-zsh|bash|-bash|sh|fish|tmux|login|nvim|vim) return 1 ;;
    claude|node|sudo|sandbox-exec) return 0 ;;
    [0-9]*.[0-9]*) return 0 ;;
    *) return 1 ;;
  esac; }
