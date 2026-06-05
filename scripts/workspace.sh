#!/usr/bin/env bash
# Ghostty + tmux workspace launcher.
#
# Opens one Ghostty window attached to a tmux session named after the
# current workspace, with four windows: dev, ai-1, ai-2, shell.
# ai-1 and ai-2 auto-run claude under separate CLAUDE_CONFIG_DIRs.
#
# Setup:
#   1. brew install --cask ghostty
#   2. brew install tmux
#   3. (optional) alias wsg=~/.scripts/workspace.sh
#   4. From inside a worktree (or any folder), run: wsg
#
# Reset:  wsg --reset    (kills the tmux session for this workspace)

set -Eeuo pipefail

# --- Workspace name derivation (mirrors ../workspace.sh) ---
common=$(git rev-parse --git-common-dir 2>/dev/null || true)
if [ -n "$common" ] && \
   [ "$(git -C "$common" rev-parse --is-bare-repository 2>/dev/null || true)" = "true" ]; then
  common_abs=$(cd "$common" && pwd)
  root=$(basename "$(dirname "$common_abs")")
  leaf=$(basename "$PWD")
  if [ "$PWD" = "$(dirname "$common_abs")" ] || [ "$leaf" = "$root" ]; then
    WS="$root"
  else
    WS="$root/$leaf"
  fi
else
  WS=$(basename "$PWD")
fi

# tmux session names can't contain "." (used for window/pane targets).
SESSION="${WS//./_}"

TMUX_CONF="$HOME/.config/tmux/tmux.conf"
GHOSTTY_CFG="$HOME/.config/ghostty/base.conf"
SOCKET=wsg

tm() { tmux -L "$SOCKET" -f "$TMUX_CONF" "$@"; }

if [ "${1-}" = "--reset" ]; then
  tm kill-session -t "$SESSION" 2>/dev/null || true
  echo "killed tmux session: $SESSION" >&2
  exit 0
fi

if [ -n "${1-}" ]; then
  echo "Usage: $(basename "$0") [--reset]" >&2
  exit 1
fi

if ! tm has-session -t "$SESSION" 2>/dev/null; then
  tm new-session -d -s "$SESSION" -n shell -c "$PWD"
  tm set-option -t "$SESSION" @workspace "$WS"
  tm new-window  -t "$SESSION:" -n dev -c "$PWD" \
    "zsh -ic 'nvim; exec zsh'"
  tm new-window  -t "$SESSION:" -n ai-1 -c "$PWD" \
    "zsh -ic 'CLAUDE_CONFIG_DIR=$HOME/.claude-account1 claude; exec zsh'"
  tm new-window  -t "$SESSION:" -n ai-2 -c "$PWD" \
    "zsh -ic 'CLAUDE_CONFIG_DIR=$HOME/.claude-account2 claude; exec zsh'"
  tm select-window -t "$SESSION:shell"
fi

# If already inside the wsg tmux server, switch in place — no new window.
if [ -n "${TMUX-}" ] && \
   [ "$(tmux display-message -p '#{socket_path}' 2>/dev/null)" = \
     "$(tmux -L "$SOCKET" display-message -p '#{socket_path}' 2>/dev/null)" ]; then
  exec tmux switch-client -t "$SESSION"
fi

# Ghostty's --command word-splits on spaces and the resulting login/bash
# wrap mangles multi-arg commands. Pass a single-path wrapper instead.
WRAPPER="${TMPDIR:-/tmp}/wsg-attach-$SESSION.sh"
cat >"$WRAPPER" <<EOF
#!/usr/bin/env bash
exec /opt/homebrew/bin/tmux -L $SOCKET -f $TMUX_CONF attach -t $SESSION
EOF
chmod +x "$WRAPPER"

open -na Ghostty --args \
  --config-file="$GHOSTTY_CFG" \
  --title="$WS" \
  --working-directory="$PWD" \
  --command="direct:$WRAPPER"
