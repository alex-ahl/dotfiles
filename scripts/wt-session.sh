#!/usr/bin/env bash
# Open (or attach) a wsg tmux session for a worktree and switch to it.
# Called from wt's post-switch hook.  $1 = worktree path.
# Session name follows the wsg convention: path relative to ~/git.
#
# Optional extra args carry an agent context handoff into the new session:
#   wt-session.sh <path> ai-1=<slug> ai-2=<slug>
# A window named on the left boots the agent resumed from <slug> instead of
# cold, loading the handoff at ~/handoffs/<slug>.md (see scripts/lib/agent.sh,
# wt-rehome.sh / handoff.md).
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

sess="${path#$HOME/git/}"

# On first creation, scaffold the same 4 windows as wsg (workspace.sh):
# shell + dev (nvim) + the agent's ai windows (see scripts/lib/agent.sh).
# The zsh -ic '<cmd>; exec zsh' wrapper (run then drop to a shell) is applied
# here; agent_launch_cmd returns just the inner command.
scaffolded=0
if ! "$TMUX_BIN" -L "$SOCK" has-session -t "$sess" 2>/dev/null; then
  "$TMUX_BIN" -L "$SOCK" new-session -d -s "$sess" -n shell -c "$path"
  "$TMUX_BIN" -L "$SOCK" set-option -t "$sess" @workspace "$sess"
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

# Resume slugs only take effect during scaffolding above. If a session already
# existed we can't apply them — fail loudly (exit 3) so a caller like wt-rehome
# knows the handoff wasn't resumed and can keep the old session as a fallback
# instead of tearing it down.
if [ "$scaffolded" = 0 ] && [ "${#RESUME_ARGS[@]}" -gt 0 ]; then
  echo "wt-session: session '$sess' already existed — resume slugs (${RESUME_ARGS[*]}) NOT applied" >&2
  exit 3
fi
