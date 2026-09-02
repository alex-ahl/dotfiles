#!/usr/bin/env bash
# Relaunch an agent pane, resuming its conversation (prefix + R in wsg).
#
# The launch string is built by the agent profile and stored nowhere, so a pane
# whose agent exited has no way back: it drops to a host shell via the
# scaffolder's `exec zsh`, and re-running wsg would boot the session cold.
# Needed most after a policy change — srt reads scripts/lib/srt-settings.json
# once at startup, so an approved domain reaches the next pane, not this one.
#
# Args: pane id, window name, pane path.
set -Eeuo pipefail

pane="${1:?pane id}"; win="${2:?window name}"; path="${3:-}"

# run-shell inherits $TMUX, so this lands on the same server without -L.
_msg() { tmux display-message "relaunch: $1"; }

sess="$(tmux display-message -p -t "$pane" '#{session_name}')"

# An agent pane reports no cwd: its process runs as the sandvault user, so
# macOS denies tmux the lookup. Same fallback status-right uses (tmux.conf).
[ -n "$path" ] || path="$(tmux display-message -p -t "$pane" '#{session_path}')"

# Launch context comes from session options, not the environment: run-shell is
# handed the *server's* env, which never had WSG_* in it, and sv's `env -i`
# keeps it out of the pane too. Guessing here would silently relaunch an
# egress-filtered pane unfiltered — the opposite of why the key was pressed.
# @wsg_agent is the sentinel: it is never empty once set, whereas an empty
# @wsg_egress legitimately means "this session runs without egress filtering".
# `|| true`: an unset user option must reach the guard below as empty, not kill
# the script through set -e before it can say why nothing happened.
WSG_AGENT="$(tmux show-options -qv -t "$sess" @wsg_agent || true)"
[ -n "$WSG_AGENT" ] || { _msg "session predates @wsg_agent — stamp it (see README) or recreate with wsg"; exit 0; }
WSG_EGRESS="$(tmux show-options -qv -t "$sess" @wsg_egress || true)"

# The profile decides sandboxed vs host from the pane's path, and run-shell's
# cwd is tmux's, not the pane's — so hand it over explicitly.
WSG_CWD="$path"
export WSG_AGENT WSG_EGRESS WSG_CWD

. "$(dirname "$0")/lib/agent.sh"

agent_is_window "$win" || { _msg "$win is not an agent window"; exit 0; }

# Same `zsh -ic '<cmd>; exec zsh'` wrapper the scaffolders use (workspace.sh,
# wt-session.sh). The profile's output carries no single quotes, so this nests.
tmux respawn-pane -k -t "$pane" -c "$path" \
  "zsh -ic '$(agent_continue_cmd "$win"); exec zsh'"
