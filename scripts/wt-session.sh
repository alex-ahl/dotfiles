#!/usr/bin/env bash
# Open (or attach) a wsg tmux session for a worktree and switch to it.
# Called from wt's post-switch hook.  $1 = worktree path.
# Session name follows the wsg convention: path relative to ~/git.
set -e

path="$1"
[ -z "$path" ] && exit 0

TMUX_BIN=/opt/homebrew/bin/tmux
SOCK=wsg

# No-op when there's no wsg server (e.g. running outside tmux).
"$TMUX_BIN" -L "$SOCK" has-session 2>/dev/null || exit 0

sess="${path#$HOME/git/}"

# On first creation, scaffold the same 4 windows as wsg (workspace.sh):
# shell + dev (nvim) + ai-1/ai-2 (claude under separate config dirs).
if ! "$TMUX_BIN" -L "$SOCK" has-session -t "$sess" 2>/dev/null; then
  "$TMUX_BIN" -L "$SOCK" new-session -d -s "$sess" -n shell -c "$path"
  "$TMUX_BIN" -L "$SOCK" set-option -t "$sess" @workspace "$sess"
  "$TMUX_BIN" -L "$SOCK" new-window -t "$sess:" -n dev  -c "$path" \
    "zsh -ic 'nvim; exec zsh'"
  "$TMUX_BIN" -L "$SOCK" new-window -t "$sess:" -n ai-1 -c "$path" \
    "zsh -ic 'CLAUDE_CONFIG_DIR=$HOME/.claude-account1 claude; exec zsh'"
  "$TMUX_BIN" -L "$SOCK" new-window -t "$sess:" -n ai-2 -c "$path" \
    "zsh -ic 'CLAUDE_CONFIG_DIR=$HOME/.claude-account2 claude; exec zsh'"
  "$TMUX_BIN" -L "$SOCK" select-window -t "$sess:shell"
fi
"$TMUX_BIN" -L "$SOCK" switch-client -t "$sess"
