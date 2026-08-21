#!/usr/bin/env bash
# handoff-session.sh — save each ai window's agent context before a wsg tmux
# session is torn down, by sending the agent's handoff command into its pane.
# Agent specifics (windows, trigger keys, output file) come from
# scripts/lib/agent.sh; default agent (claude) writes ~/handoffs/ via `/handoff <slug>`.
#
# Runs unattended only if `/handoff`'s read-only steps are pre-allowed in the
# target Claude's settings.json — else Claude prompts for approval, no file
# appears, and the caller keeps the session. We never inject approvals into a live Claude.
#
# Subcommands:
#   handoff-session.sh fire  <session>            # trigger /handoff in Claude panes; prints "<window>|<pane>|<slug>" lines
#   handoff-session.sh await <timeout> <pair...>  # wait for each slug's file to settle (slug is the last '|'-field)
#   handoff-session.sh check <pair-or-slug...>    # exit 0 iff every slug's file has settled now
#   handoff-session.sh run   <session>            # fire + await for one session (blocking)
#
# "settled" = file exists, non-empty, and unwritten for >=3s (so we don't proceed mid-write).

. "$(dirname "$0")/lib/agent.sh"     # sets HANDOFF_DIR; provides agent_* helpers
WSG_SOCK="${WSG_SOCK:-wsg}"
DEFAULT_TIMEOUT=180

_slugify() { printf '%s' "$1" | tr '/ ' '--' | tr -cd '[:alnum:]._-'; }

# settled? <file> : exists, non-empty, no write in last 3s
_settled() {
  local f="$1" m now
  [ -s "$f" ] || return 1
  m="$(stat -f %m "$f" 2>/dev/null || echo 0)"
  now="$(date +%s)"
  [ "$((now - m))" -ge 3 ]
}

# fire <session> -> send handoff keys to each agent pane; print "<window>|<pane>|<slug>".
cmd_fire() {
  local sess="$1"
  mkdir -p "$HANDOFF_DIR"
  tmux -L "$WSG_SOCK" list-panes -s -t "$sess" -F '#{window_name}|#{pane_id}|#{pane_current_command}' 2>/dev/null \
    | while IFS='|' read -r wname pid cmd; do
        # Gate on window name, not just command: agent_is_cmd matches a bare
        # `node`, so a node dev-server/REPL in the shell/dev window would
        # otherwise get handoff keys typed into it.
        agent_is_window "$wname" || continue
        agent_is_cmd "$cmd" || continue
        local base slug n
        base="$(_slugify "$sess")-$(_slugify "$wname")"
        # Reserve the slug's file atomically (noclobber), not by existence test:
        # the agent writes it later, so two concurrent fires would both see "no
        # file" and pick the same slug, clobbering one handoff. "settled" requires
        # non-empty, so this placeholder never counts as done.
        slug="$base"; n=2
        until (set -o noclobber; : > "$(agent_handoff_file "$slug")") 2>/dev/null; do
          slug="$base-$n"; n=$((n + 1))
        done
        tmux -L "$WSG_SOCK" send-keys -t "$pid" -l "$(agent_handoff_keys "$slug")"
        sleep 0.4
        tmux -L "$WSG_SOCK" send-keys -t "$pid" Enter
        echo "$wname|$pid|$slug"
      done
}

# await <timeout> <pane|slug>... -> wait for each slug's file to settle.
cmd_await() {
  local timeout="$1"; shift
  [ "$#" -eq 0 ] && return 0
  local waited=0 entry slug all
  while :; do
    all=1
    for entry in "$@"; do
      slug="${entry##*|}"
      _settled "$(agent_handoff_file "$slug")" || { all=0; break; }
    done
    [ "$all" = 1 ] && return 0
    [ "$waited" -ge "$timeout" ] && return 1
    sleep 2; waited=$((waited + 2))
  done
}

# check <pane|slug or slug>... -> 0 iff all settled now.
cmd_check() {
  local e
  for e in "$@"; do _settled "$(agent_handoff_file "${e##*|}")" || return 1; done
  return 0
}

# run <session> -> fire + await (blocking single session).
cmd_run() {
  local pairs
  pairs="$(cmd_fire "$1" | tr '\n' ' ')"
  [ -z "${pairs// /}" ] && return 0   # no Claude panes — nothing to save
  # shellcheck disable=SC2086
  cmd_await "$DEFAULT_TIMEOUT" $pairs
}

case "${1:-}" in
  fire)  shift; cmd_fire "$@" ;;
  await) shift; cmd_await "$@" ;;
  check) shift; cmd_check "$@" ;;
  run)   shift; cmd_run "$@" ;;
  *) echo "usage: handoff-session.sh {fire <session>|await <timeout> <pair...>|check <pair-or-slug...>|run <session>}" >&2; exit 2 ;;
esac
