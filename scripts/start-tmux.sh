#!/usr/bin/env bash
# Default command for plain ghostty launches: drop into tmux on the wsg socket,
# attaching to (or creating) a 'home' session in ~/git. wsg's own ghostty
# launches override this via --command to attach to the workspace session.
set -e
# Ghostty launches us via `command = direct:…`, which bypasses the login shell,
# so .zprofile never runs and Homebrew isn't on PATH. Set it here so the tmux
# server (and all it spawns: popups, run-shell, panes) inherits brew's bin dir.
# Without this, fzf-based popups silently fail with "command not found".
for b in /opt/homebrew/bin/brew /home/linuxbrew/.linuxbrew/bin/brew; do
  [ -x "$b" ] && { eval "$("$b" shellenv)"; break; }
done
exec tmux -L wsg -f ~/.config/tmux/tmux.conf \
  new-session -A -s home -n shell -c "$HOME/git"
