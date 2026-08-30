#!/usr/bin/env bash
# Agent adapter. `source` this, then call agent_* functions. Select the agent
# with $WSG_AGENT (default: claude); add one via a profile in
# scripts/agents.d/<name>.sh defining the seven agent_* funcs (see
# docs/superpowers/specs/2026-08-16-agent-adapter-design.md).
# Named WSG_AGENT not AI_AGENT: the Claude Code runtime already exports AI_AGENT
# in every pane, which would override our selector.
: "${WSG_AGENT:=claude}"
: "${HANDOFF_DIR:=$HOME/handoffs}"
_p="$(cd "$(dirname "${BASH_SOURCE[0]}")/../agents.d" && pwd)/${WSG_AGENT}.sh"
[ -r "$_p" ] || { echo "agent: unknown WSG_AGENT '$WSG_AGENT' ($_p missing)" >&2; exit 1; }
. "$_p"

# Derived from the profile's window list; used by handoff-session.sh's pane gate.
agent_is_window() { case " $(agent_windows) " in *" $1 "*) return 0 ;; *) return 1 ;; esac; }
