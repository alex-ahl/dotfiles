#!/usr/bin/env bash
# tmux status badge for a pane's agent. Prints "sandboxed", "host", or nothing.
#
# Called from status-right as #(agent-badge.sh '#{pane_pid}'). The badge used to
# be pure tmux formats keyed on pane_start_command ("sv shell") and the window
# name (ai-*), which only ever matched the wsg workspace windows — an agent
# started by hand in the `home` session or in a shell/dev window went unbadged.
# The pane's process tree is the honest signal, and it's agent-agnostic.
#
#   sandboxed = something under the pane went through sandbox-exec (sv's jail),
#               or through srt (sv -x + WSG_EGRESS, where srt owns the seatbelt)
#   host      = the agent binary runs under the pane, unsandboxed
#
# A bare `sudo` matches neither — which is the whole point; the old format had to
# special-case it to avoid reading as "sandboxed", the opposite of the truth.
set -u

. "$(dirname "$0")/lib/agent.sh"

pane_pid="${1-}"
case "$pane_pid" in ''|*[!0-9]*) exit 0 ;; esac

# ps once, then walk down from the pane's shell. awk (not bash arrays): macOS
# ships bash 3.2, which has no associative arrays.
badge=$(ps -Ao pid=,ppid=,args= | awk -v root="$pane_pid" -v agent="$(agent_proc_name)" '
  {
    pid = $1; ppid = $2
    $1 = ""; $2 = ""; sub(/^ +/, "")
    cmd[pid] = $0
    kid[ppid, ++cnt[ppid]] = pid
  }
  END {
    q[1] = root; head = 1; tail = 1
    while (head <= tail) {
      p = q[head++]
      # sv -x leaves no sandbox-exec argv, and srt execs into zsh — so match
      # the live `node .../bin/srt` instead. "/srt " keeps it off the pane
      # shell (which says " srt", no slash) and off srt-settings.json.
      if (cmd[p] ~ /sandbox-exec/ || cmd[p] ~ /\/srt /) sandboxed = 1
      split(cmd[p], w, " "); base = w[1]; sub(/.*\//, "", base)
      if (base == agent) found = 1
      for (i = 1; i <= cnt[p]; i++) q[++tail] = kid[p, i]
    }
    if (sandboxed)  print "sandboxed"
    else if (found) print "host"
  }
')

# Colors mirror the window-role palette in tmux.conf (orange = agent, red = warn).
case "$badge" in
  sandboxed) printf '#[fg=#F9A03F,bold]sandboxed#[default]  ' ;;
  host)      printf '#[fg=#E05252,bold]host#[default]  ' ;;
esac
