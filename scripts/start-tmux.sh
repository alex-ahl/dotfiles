#!/usr/bin/env bash
# Default command for plain ghostty launches: drop into tmux on the
# wsg socket, attaching to (or creating) a 'main' session in ~/git.
# wsg's own ghostty launches override this via --command, so they
# attach to the workspace session instead.
set -e
exec /opt/homebrew/bin/tmux -L wsg -f ~/.config/tmux/tmux.conf \
  new-session -A -s home -n shell -c "$HOME/git"
