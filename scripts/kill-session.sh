#!/usr/bin/env bash
# fzf-pick a wsg session and kill it. Same picker UI as `prefix + f`
# (workspace + path columns, session name hidden). Mirrors `prefix + X`'s
# guards: refuses to kill the 'home' fallback, and if you kill the session
# you're attached to, jumps back to 'home' first so the client survives.
# Must run inside a display-popup (-E) so fzf has a terminal.

TMUX_BIN=/opt/homebrew/bin/tmux
cur=$("$TMUX_BIN" display-message -p '#S')

target=$("$TMUX_BIN" ls -F '#{?#{@workspace},#{@workspace},#{session_name}}|#{s|'"$HOME"'|~|:#{session_path}}|#{session_name}' \
  | column -t -s '|' \
  | fzf --reverse --with-nth=1,2 --prompt 'kill> ' \
  | awk '{print $NF}')

[ -z "$target" ] && exit 0

if [ "$target" = home ]; then
  "$TMUX_BIN" display-message "home session cannot be killed"
  exit 0
fi

if [ "$target" = "$cur" ]; then
  "$TMUX_BIN" new-session -dA -s home -n shell -c "$HOME/git"
  "$TMUX_BIN" switch-client -t home
fi

"$TMUX_BIN" kill-session -t "$target"
