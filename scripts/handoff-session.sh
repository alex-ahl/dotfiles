#!/usr/bin/env bash
# handoff-session.sh — save the Claude context of a wsg tmux session via the
# `/handoff` command before the session is torn down. Covers both Claude
# instances (ai-1 = account1, ai-2 = account2); `/handoff` is symlinked into
# both configs and writes to the shared ~/handoffs/, so one trigger fits all.
#
# For this to run unattended, `/handoff`'s read-only steps must be allowed in
# the target Claude's settings (see the `claude` package's settings.json
# permissions). Without that, the running Claude prompts for approval, the file
# never appears, and the caller leaves that session intact. We never inject
# approvals into another live Claude.
#
# Subcommands:
#   handoff-session.sh fire  <session>            # trigger /handoff in Claude panes; prints "<pane>|<slug>" lines
#   handoff-session.sh await <timeout> <pair...>  # wait for each slug's file to settle (pairs are "<pane>|<slug>")
#   handoff-session.sh check <pair-or-slug...>    # exit 0 iff every slug's file has settled now
#   handoff-session.sh run   <session>            # fire + await for one session (blocking)
#
# A file is "settled" once it exists, is non-empty, and hasn't been written to
# for >=3s (so we don't proceed while /handoff is mid-write).

HANDOFF_DIR="${HANDOFF_DIR:-$HOME/handoffs}"
WSG_SOCK="${WSG_SOCK:-wsg}"
DEFAULT_TIMEOUT=180

# True when a pane's foreground command is a live Claude (not a shell). Claude
# Code reports its version (e.g. "2.1.165") as the process command.
_is_claude_cmd() {
  case "$1" in
    "" | zsh | -zsh | bash | -bash | sh | fish | tmux | login | nvim | vim) return 1 ;;
    claude | node) return 0 ;;
    [0-9]*.[0-9]*) return 0 ;;
    *) return 1 ;;
  esac
}

_slugify() { printf '%s' "$1" | tr '/ ' '--' | tr -cd '[:alnum:]._-'; }

# settled? <file> : exists, non-empty, no write in last 3s
_settled() {
  local f="$1" m now
  [ -s "$f" ] || return 1
  m="$(stat -f %m "$f" 2>/dev/null || echo 0)"
  now="$(date +%s)"
  [ "$((now - m))" -ge 3 ]
}

# fire <session> -> trigger /handoff in each Claude pane; print "<pane>|<slug>".
cmd_fire() {
  local sess="$1"
  mkdir -p "$HANDOFF_DIR"
  tmux -L "$WSG_SOCK" list-panes -s -t "$sess" -F '#{window_name}|#{pane_id}|#{pane_current_command}' 2>/dev/null \
    | while IFS='|' read -r wname pid cmd; do
        _is_claude_cmd "$cmd" || continue
        local base slug n
        base="$(_slugify "$sess")-$(_slugify "$wname")"
        slug="$base"; n=2
        while [ -e "$HANDOFF_DIR/$slug.md" ]; do slug="$base-$n"; n=$((n + 1)); done
        tmux -L "$WSG_SOCK" send-keys -t "$pid" -l "/handoff $slug"
        sleep 0.4
        tmux -L "$WSG_SOCK" send-keys -t "$pid" Enter
        echo "$pid|$slug"
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
      _settled "$HANDOFF_DIR/$slug.md" || { all=0; break; }
    done
    [ "$all" = 1 ] && return 0
    [ "$waited" -ge "$timeout" ] && return 1
    sleep 2; waited=$((waited + 2))
  done
}

# check <pane|slug or slug>... -> 0 iff all settled now.
cmd_check() {
  local e
  for e in "$@"; do _settled "$HANDOFF_DIR/${e##*|}.md" || return 1; done
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
