# Agent adapter for worktree/session scripts

**Date:** 2026-08-16
**Status:** Approved (design)

## Problem

The dotfiles worktree + tmux session scripts hardcode Claude Code specifics in
several places: the `claude` binary, the `CLAUDE_CONFIG_DIR` two-account
convention (`ai-1`→account1, `ai-2`→account2), the `/handoff` + `/resume`
context commands, and the `~/handoffs/` file convention. The user intends to
switch to (or add) another terminal agent such as **opencode** later. Adding an
agent today would mean editing every coupled script.

## Goal

Introduce a thin adapter so agent-specific behavior lives in one profile file
per agent. Adding an agent becomes an additive change (one new file), with no
edits to the workflow scripts. This task implements the adapter and the
**Claude** profile only; behavior must remain byte-for-byte identical
(`WSG_AGENT` defaults to `claude`). The opencode profile comes later, once its
CLI (session resume mechanism, context-dump equivalent) is verified.

## Non-goals

- No opencode profile in this task.
- No new test framework or dependencies.
- No change to the stashed resurrect setup (`claude-resume.sh` stays in
  `~/.local/share/dotfiles-stash/tmux-resurrect/`; see that dir's `RESTORE.md`).

## Architecture (Approach A: sourced shell library + profile files)

Two new files, reachable through the existing `~/.scripts` → `scripts/` symlink:

- `scripts/lib/agent.sh` — loader
- `scripts/agents.d/claude.sh` — Claude profile

Call sites `source` the loader once and call `agent_*` functions. The agent is
selected by `$WSG_AGENT` (default `claude`).

### Loader — `scripts/lib/agent.sh`

```sh
#!/usr/bin/env bash
: "${WSG_AGENT:=claude}"
: "${HANDOFF_DIR:=$HOME/handoffs}"
_p="$(cd "$(dirname "${BASH_SOURCE[0]}")/../agents.d" && pwd)/${WSG_AGENT}.sh"
[ -r "$_p" ] || { echo "agent: unknown WSG_AGENT '$WSG_AGENT' ($_p missing)" >&2; exit 1; }
. "$_p"
agent_is_window() { case " $(agent_windows) " in *" $1 "*) return 0 ;; *) return 1 ;; esac; }
```

Location is resolved via `BASH_SOURCE`, so it is independent of the caller's cwd
or `$0`. All callers are `#!/usr/bin/env bash`, so `BASH_SOURCE` is available.

### The contract

Each profile defines six functions; the loader adds `agent_is_window`.

| Function | Returns |
|---|---|
| `agent_windows` | space-separated ai window names (`ai-1 ai-2`) |
| `agent_launch_cmd <win> <slug>` | inner pane command; cold if slug empty, else resumed. Caller wraps in `zsh -ic '<cmd>; exec zsh'` |
| `agent_continue_cmd <win>` | inner command to relaunch resuming latest (for the stashed resurrect wrapper; no in-repo caller yet) |
| `agent_handoff_keys <slug>` | literal text sent into the pane to save context |
| `agent_handoff_file <slug>` | path saved context lands at |
| `agent_is_cmd <pane_cmd>` | exit 0 if a pane's foreground command is a live agent |
| `agent_is_window <win>` | (loader-provided) exit 0 if `<win>` is in `agent_windows` |

The `agent_launch_cmd` result is the **inner** command only. The
`zsh -ic '<cmd>; exec zsh'` wrapper (run then drop to a shell) is a tmux-pane
concern applied by the caller — the same idiom the `dev` window already uses.

### Claude profile — `scripts/agents.d/claude.sh`

```sh
#!/usr/bin/env bash
agent_windows() { echo "ai-1 ai-2"; }
_agent_env() { case "$1" in
    ai-1) printf 'CLAUDE_CONFIG_DIR=%s/.claude-account1 ' "$HOME" ;;
    ai-2) printf 'CLAUDE_CONFIG_DIR=%s/.claude-account2 ' "$HOME" ;;
  esac; }
agent_launch_cmd()   { [ -n "$2" ] && printf '%sclaude "/resume %s"' "$(_agent_env "$1")" "$2" \
                                    || printf '%sclaude' "$(_agent_env "$1")"; }
agent_continue_cmd() { printf '%sclaude --continue' "$(_agent_env "$1")"; }
agent_handoff_keys() { printf '/handoff %s' "$1"; }
agent_handoff_file() { printf '%s/%s.md' "$HANDOFF_DIR" "$1"; }
agent_is_cmd()       { case "$1" in
    ""|zsh|-zsh|bash|-bash|sh|fish|tmux|login|nvim|vim) return 1 ;;
    claude|node) return 0 ;; [0-9]*.[0-9]*) return 0 ;; *) return 1 ;;
  esac; }
```

## Call-site changes

### `workspace.sh`

Replace the two hardcoded `ai-1`/`ai-2` `new-window` lines with a loop over
`agent_windows`. `dev` and `shell` windows unchanged.

```sh
for w in $(agent_windows); do
  inner="$(agent_launch_cmd "$w" "")"
  tm new-window -t "$SESSION:" -n "$w" -c "$PWD" "zsh -ic '$inner; exec zsh'"
done
```

### `wt-session.sh`

Drop `claude_cmd()` and the `RESUME_AI1/RESUME_AI2` variables. Keep resume args
in an array and look up per window:

```sh
RESUME_ARGS=("$@")
_slug_for() { local a; for a in "${RESUME_ARGS[@]}"; do
    case "$a" in "$1="*) printf '%s' "${a#"$1"=}"; return ;; esac; done; }
...
for w in $(agent_windows); do
  inner="$(agent_launch_cmd "$w" "$(_slug_for "$w")")"
  "$TMUX_BIN" -L "$SOCK" new-window -t "$sess:" -n "$w" -c "$path" "zsh -ic '$inner; exec zsh'"
done
```

The "session already existed → resume slugs NOT applied → exit 3" guard stays,
generalized to "any resume slug was passed" rather than checking two named vars.

### `handoff-session.sh`

Behavior-preserving swaps:

- remove the local `_is_claude_cmd`; use `agent_is_cmd`
- gate `case "$wname" in ai-*)` → `agent_is_window "$wname" || continue`
- `send-keys -l "/handoff $slug"` → `-l "$(agent_handoff_keys "$slug")"`
- settle path `"$HANDOFF_DIR/$slug.md"` (in `fire` reserve, `await`, `check`)
  → `"$(agent_handoff_file "$slug")"`
- remove its own `HANDOFF_DIR=` default (loader owns it); `WSG_SOCK` stays

Deliberate micro-change: the window gate goes from glob `ai-*` to exact
membership in `agent_windows`. Identical in practice (only `ai-1`/`ai-2` exist),
just tighter.

### No functional change

`wt-rehome.sh` and `wt-prune.sh` already carry context via window names read
from `handoff-session.sh` output, which is agent-neutral. Only Claude-specific
*wording* in comments/headers is updated where it would now mislead.

## Verification — golden-output diff

No persistent test file. A throwaway scratchpad harness prints, for each ai
window, the new adapter's strings (cold launch, resume launch, continue, handoff
keys, handoff file) and diffs them against the exact strings the current
committed scripts produce (extracted from `git show HEAD:…`). Pass = empty diff.

Then one live smoke run: create a throwaway worktree, confirm `wt-session.sh`
scaffolds `ai-1`/`ai-2` with Claude launching under the correct
`CLAUDE_CONFIG_DIR`, and tear it down.

## Adding opencode later (informational)

Drop `scripts/agents.d/opencode.sh` defining the same six functions. Before
that, verify against opencode's real CLI: (1) how it resumes a specific/last
session, and (2) whether it has a `/handoff`-style context dump (may need a
custom command). `agent_windows` can map to one window or to two different
models. No workflow-script edits required.
```
