#!/usr/bin/env bash
# Open (or attach) a wsg tmux session for a worktree and switch to it.
# Called from wt's post-switch hook.  $1 = worktree path.
# Session name follows the wsg convention: path relative to ~/git.
#
# Optional extra args carry a Claude context handoff into the new session:
#   wt-session.sh <path> ai-1=<slug> ai-2=<slug>
# A window named on the left boots `claude "/resume <slug>"` instead of cold,
# loading the handoff at ~/handoffs/<slug>.md (see wt-rehome.sh / handoff.md).
set -e

path="$1"; shift || true
[ -z "$path" ] && exit 0

# Resume slugs per ai window, from the optional "ai-N=<slug>" args above.
RESUME_AI1=""; RESUME_AI2=""
for a in "$@"; do
  case "$a" in
    ai-1=*) RESUME_AI1="${a#ai-1=}" ;;
    ai-2=*) RESUME_AI2="${a#ai-2=}" ;;
  esac
done

TMUX_BIN=/opt/homebrew/bin/tmux
SOCK=wsg

# No-op when there's no wsg server (e.g. running outside tmux).
"$TMUX_BIN" -L "$SOCK" has-session 2>/dev/null || exit 0

sess="${path#$HOME/git/}"

# Build a claude launch command for one ai window. $1 = config dir, $2 = resume
# slug (""=cold). Quoting: the result is run by tmux via `sh -c`, so the zsh -ic
# payload is single-quoted; the resume prompt sits in double quotes inside it.
claude_cmd() {
  local cfg="$1" slug="$2" inner
  if [ -n "$slug" ]; then
    inner="CLAUDE_CONFIG_DIR=$cfg claude \"/resume $slug\""
  else
    inner="CLAUDE_CONFIG_DIR=$cfg claude"
  fi
  printf "zsh -ic '%s; exec zsh'" "$inner"
}

# On first creation, scaffold the same 4 windows as wsg (workspace.sh):
# shell + dev (nvim) + ai-1/ai-2 (claude under separate config dirs).
scaffolded=0
if ! "$TMUX_BIN" -L "$SOCK" has-session -t "$sess" 2>/dev/null; then
  "$TMUX_BIN" -L "$SOCK" new-session -d -s "$sess" -n shell -c "$path"
  "$TMUX_BIN" -L "$SOCK" set-option -t "$sess" @workspace "$sess"
  "$TMUX_BIN" -L "$SOCK" new-window -t "$sess:" -n dev  -c "$path" \
    "zsh -ic 'nvim; exec zsh'"
  "$TMUX_BIN" -L "$SOCK" new-window -t "$sess:" -n ai-1 -c "$path" \
    "$(claude_cmd "$HOME/.claude-account1" "$RESUME_AI1")"
  "$TMUX_BIN" -L "$SOCK" new-window -t "$sess:" -n ai-2 -c "$path" \
    "$(claude_cmd "$HOME/.claude-account2" "$RESUME_AI2")"
  "$TMUX_BIN" -L "$SOCK" select-window -t "$sess:shell"
  scaffolded=1
fi
"$TMUX_BIN" -L "$SOCK" switch-client -t "$sess"

# Resume slugs only take effect during scaffolding above. If a session already
# existed we can't apply them — fail loudly (exit 3) so a caller like wt-rehome
# knows the handoff wasn't resumed and can keep the old session as a fallback
# instead of tearing it down.
if [ "$scaffolded" = 0 ] && { [ -n "$RESUME_AI1" ] || [ -n "$RESUME_AI2" ]; }; then
  echo "wt-session: session '$sess' already existed — resume slugs (ai-1='$RESUME_AI1' ai-2='$RESUME_AI2') NOT applied" >&2
  exit 3
fi
