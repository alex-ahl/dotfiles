#!/usr/bin/env bash
# Open (or attach) a wsg tmux session for a worktree and switch to it.
# Called from wt's post-switch hook. $1 = worktree path.
# Session name = path relative to ~/git (wsg convention).
#
# Optional extra args carry an agent handoff into the new session:
#   wt-session.sh <path> ai-1=<slug> ai-2=<slug>
# Each named window boots the agent resumed from <slug> (loading
# ~/handoffs/<slug>.md) instead of cold. See scripts/lib/agent.sh, wt-rehome.sh.
set -e

. "$(dirname "$0")/lib/agent.sh"

path="$1"; shift || true
[ -z "$path" ] && exit 0

# Resume slugs per ai window, from the optional "<window>=<slug>" args above.
RESUME_ARGS=("$@")
_slug_for() {  # $1 = window name -> prints its resume slug, or nothing
  local a
  for a in "${RESUME_ARGS[@]}"; do
    case "$a" in "$1="*) printf '%s' "${a#"$1"=}"; return ;; esac
  done
}

TMUX_BIN=/opt/homebrew/bin/tmux
SOCK=wsg

# No-op when there's no wsg server (e.g. running outside tmux).
"$TMUX_BIN" -L "$SOCK" has-session 2>/dev/null || exit 0

# ~/git is a symlink into the sandvault share, but git reports canonical paths.
GIT_ROOT="${GIT_ROOT:-$HOME/git}"
ROOT_REAL="$(cd "$GIT_ROOT" && pwd -P)"
sess="${path#"$ROOT_REAL"/}"; sess="${sess#"$GIT_ROOT"/}"

# On first creation, scaffold the same windows as wsg (workspace.sh):
# shell + dev (nvim) + the agent's ai windows (see scripts/lib/agent.sh).
# The `zsh -ic '<cmd>; exec zsh'` wrapper (run, then drop to a shell) is added
# here; agent_launch_cmd returns just the inner command.
scaffolded=0
if ! "$TMUX_BIN" -L "$SOCK" has-session -t "$sess" 2>/dev/null; then
  "$TMUX_BIN" -L "$SOCK" new-session -d -s "$sess" -n shell -c "$path"
  "$TMUX_BIN" -L "$SOCK" set-option -t "$sess" @workspace "$sess"
  # Launch context for agent-relaunch.sh: neither the tmux server env nor the
  # pane (sv uses env -i) carries WSG_*, so record it where R can read it back.
  "$TMUX_BIN" -L "$SOCK" set-option -t "$sess" @wsg_agent  "$WSG_AGENT"
  "$TMUX_BIN" -L "$SOCK" set-option -t "$sess" @wsg_egress "${WSG_EGRESS:-}"
  "$TMUX_BIN" -L "$SOCK" new-window -t "$sess:" -n dev  -c "$path" \
    "zsh -ic 'nvim; exec zsh'"
  for w in $(agent_windows); do
    inner="$(agent_launch_cmd "$w" "$(_slug_for "$w")")"
    "$TMUX_BIN" -L "$SOCK" new-window -t "$sess:" -n "$w" -c "$path" \
      "zsh -ic '$inner; exec zsh'"
  done
  "$TMUX_BIN" -L "$SOCK" select-window -t "$sess:shell"
  scaffolded=1
fi
"$TMUX_BIN" -L "$SOCK" switch-client -t "$sess"

# Resume slugs only apply during scaffolding. If the session already existed we
# can't apply them — fail loudly (exit 3) so a caller like wt-rehome knows the
# handoff wasn't resumed and keeps the old session as a fallback.
if [ "$scaffolded" = 0 ] && [ "${#RESUME_ARGS[@]}" -gt 0 ]; then
  echo "wt-session: session '$sess' already existed — resume slugs (${RESUME_ARGS[*]}) NOT applied" >&2
  exit 3
fi
