#!/usr/bin/env bash
# Claude Code. Two ai windows, one per account config dir (ai-1->1, ai-2->2).
agent_windows() { echo "ai-1 ai-2"; }

# window -> "VAR=VAL " env prefix (trailing space), or empty for unknown windows.
# $HOME stays unexpanded: it must resolve to the sandvault home, not this one.
_agent_env() { case "$1" in
    ai-1) printf 'CLAUDE_CONFIG_DIR=\\$HOME/.claude-account1 ' ;;
    ai-2) printf 'CLAUDE_CONFIG_DIR=\\$HOME/.claude-account2 ' ;;
  esac; }

# Deployed by install.sh, deliberately outside this repo and outside the share:
# srt reads it as sandvault-$USER, which cannot see /Users/$USER, and anything
# under the share is group-writable by that account (sv re-grants it on every
# rebuild). Plain argv — srt's -s is not shell-expanded, so no \$HOME here.
_agent_user="${USER:-$(id -un)}"
_agent_srt_settings="/Users/Shared/$_agent_user-policy/srt-settings.json"
_agent_share="/Users/Shared/sv-$_agent_user"

# Sandbox invocation, up to and including `zsh -lc`. Default is sandvault alone.
# WSG_EGRESS=1 adds srt's domain allowlist (source: scripts/lib/srt-settings.json,
# deployed to the path above by install.sh). It needs `sv -x`: seatbelt does not
# nest and srt is itself sandbox-exec, so this gives one seatbelt each —
# sandvault the separate UID, srt the policy.
# srt must wrap zsh, never `srt -c '<string>'`: that runs bash, which skips
# .zshenv, so the gh token router's function would not exist (see shared/gh-token.sh).
# ${PWD:A}, not $PWD: .zshrc re-enters the share through ~/git so the prompt can
# shorten it, which leaves $PWD under a home the other account cannot traverse
# (0750). :A resolves it back — a no-op when the pane never normalised it.
# Outside the share the sandbox account cannot traverse the path at all — this
# repo now lives under /Users/$USER (0750) — so `sv shell` would fail. Launch on
# the host instead; agent-badge.sh labels the pane "host" on its own.
# WSG_CWD: agent-relaunch.sh runs from tmux's cwd, not the pane's, so it says
# which path the pane is for.
_agent_sandbox() {
  case "$(cd "${WSG_CWD:-$PWD}" 2>/dev/null && pwd -P)" in
    "$_agent_share"/*) ;;
    *) printf 'zsh -lc'; return ;;
  esac
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
