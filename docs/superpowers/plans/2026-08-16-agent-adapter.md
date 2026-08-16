# Agent Adapter Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extract Claude-specific behavior from the worktree/session scripts into a small adapter (loader + per-agent profile) so a future agent (opencode) can be added without editing the workflow scripts.

**Architecture:** A sourced shell library `scripts/lib/agent.sh` selects a profile from `scripts/agents.d/<name>.sh` via `$AI_AGENT` (default `claude`). Profiles expose six `agent_*` functions; the loader adds `agent_is_window`. Call sites (`workspace.sh`, `wt-session.sh`, `handoff-session.sh`) source the loader and call those functions. This task ships Claude only, behavior byte-for-byte identical.

**Tech Stack:** POSIX-ish bash (must run under macOS `/usr/bin/env bash`, avoid bash-4-only features), tmux (`-L wsg` socket), git worktrees.

## Global Constraints

- Branch: `agent-adapter`. All commits land here.
- `AI_AGENT` defaults to `claude`; existing behavior must be byte-for-byte identical.
- `$HOME` is `/Users/alex`; account dirs are `~/.claude-account1` / `~/.claude-account2`.
- No new dependencies, no persistent test framework. Verification is a throwaway golden-output diff (scratchpad) plus one live smoke run.
- Avoid bash-4-only syntax (target macOS bash 3.2 compatibility): plain indexed arrays and `"${arr[@]}"` are fine; no associative arrays, no `${var,,}`.
- Scratchpad dir for throwaway files: `/private/tmp/claude-501/-Users-alex-git-dotfiles/1b49cb7e-2388-48a7-ab74-31203afcf954/scratchpad`.

---

### Task 1: Adapter loader + Claude profile

**Files:**
- Create: `scripts/lib/agent.sh`
- Create: `scripts/agents.d/claude.sh`
- Verify (throwaway, not committed): `<scratchpad>/agent-golden.sh`, `<scratchpad>/agent-golden.expected`

**Interfaces:**
- Produces (each profile defines; loader adds the last):
  - `agent_windows` → prints space-separated window names, e.g. `ai-1 ai-2`
  - `agent_launch_cmd <win> <slug>` → prints inner pane command; cold if `<slug>` empty, else resumed
  - `agent_continue_cmd <win>` → prints inner command to relaunch resuming latest
  - `agent_handoff_keys <slug>` → prints literal text to send into a pane to save context
  - `agent_handoff_file <slug>` → prints path saved context lands at
  - `agent_is_cmd <pane_cmd>` → exit 0 if a pane's foreground command is a live agent
  - `agent_is_window <win>` → (loader) exit 0 if `<win>` ∈ `agent_windows`

- [ ] **Step 1: Create the loader**

Create `scripts/lib/agent.sh`:

```sh
#!/usr/bin/env bash
# Agent adapter. `source` this, then call agent_* functions. Select the agent
# with $AI_AGENT (default: claude). Add an agent by dropping a profile in
# scripts/agents.d/<name>.sh that defines the six agent_* functions documented
# in docs/superpowers/specs/2026-08-16-agent-adapter-design.md.
: "${AI_AGENT:=claude}"
: "${HANDOFF_DIR:=$HOME/handoffs}"
_p="$(cd "$(dirname "${BASH_SOURCE[0]}")/../agents.d" && pwd)/${AI_AGENT}.sh"
[ -r "$_p" ] || { echo "agent: unknown AI_AGENT '$AI_AGENT' ($_p missing)" >&2; exit 1; }
. "$_p"

# Derived from the profile's window list; used by handoff-session.sh's pane gate.
agent_is_window() { case " $(agent_windows) " in *" $1 "*) return 0 ;; *) return 1 ;; esac; }
```

- [ ] **Step 2: Create the Claude profile**

Create `scripts/agents.d/claude.sh`:

```sh
#!/usr/bin/env bash
# Claude Code. Two ai windows, one per account config dir (ai-1->1, ai-2->2).
agent_windows() { echo "ai-1 ai-2"; }

# window -> "VAR=VAL " env prefix (trailing space), or empty for unknown windows.
_agent_env() { case "$1" in
    ai-1) printf 'CLAUDE_CONFIG_DIR=%s/.claude-account1 ' "$HOME" ;;
    ai-2) printf 'CLAUDE_CONFIG_DIR=%s/.claude-account2 ' "$HOME" ;;
  esac; }

# window, resume-slug ("" = cold).
agent_launch_cmd() {
  if [ -n "$2" ]; then printf '%sclaude "/resume %s"' "$(_agent_env "$1")" "$2"
  else                 printf '%sclaude'               "$(_agent_env "$1")"; fi
}
agent_continue_cmd() { printf '%sclaude --continue' "$(_agent_env "$1")"; }
agent_handoff_keys() { printf '/handoff %s' "$1"; }
agent_handoff_file() { printf '%s/%s.md' "$HANDOFF_DIR" "$1"; }

# pane_current_command -> 0 if it's a live Claude. Claude Code reports its
# version (e.g. "2.1.165") as the process command; a bare `node` also counts.
agent_is_cmd() { case "$1" in
    ""|zsh|-zsh|bash|-bash|sh|fish|tmux|login|nvim|vim) return 1 ;;
    claude|node) return 0 ;;
    [0-9]*.[0-9]*) return 0 ;;
    *) return 1 ;;
  esac; }
```

- [ ] **Step 3: Make both files executable-safe and syntax-check**

Run:
```bash
chmod +x scripts/lib/agent.sh scripts/agents.d/claude.sh
bash -n scripts/lib/agent.sh && bash -n scripts/agents.d/claude.sh && echo SYNTAX_OK
command -v shellcheck >/dev/null && shellcheck -x scripts/lib/agent.sh scripts/agents.d/claude.sh || echo "shellcheck not installed — skipping"
```
Expected: `SYNTAX_OK` (shellcheck clean or skipped).

- [ ] **Step 4: Write the golden harness**

Create `<scratchpad>/agent-golden.sh` (substitute the real scratchpad path):

```sh
#!/usr/bin/env bash
set -e
. "$HOME/.scripts/lib/agent.sh"          # AI_AGENT unset -> claude
echo "windows: $(agent_windows)"
echo "launch ai-1 cold: $(agent_launch_cmd ai-1 "")"
echo "launch ai-2 cold: $(agent_launch_cmd ai-2 "")"
echo "launch ai-1 resume: $(agent_launch_cmd ai-1 myslug)"
echo "launch ai-2 resume: $(agent_launch_cmd ai-2 myslug)"
echo "continue ai-1: $(agent_continue_cmd ai-1)"
echo "continue ai-2: $(agent_continue_cmd ai-2)"
echo "handoff keys: $(agent_handoff_keys myslug)"
echo "handoff file: $(agent_handoff_file myslug)"
for w in $(agent_windows); do
  inner="$(agent_launch_cmd "$w" "")"
  echo "wrapped $w cold: zsh -ic '$inner; exec zsh'"
done
for c in claude node 2.1.165 zsh nvim "" tmux; do
  if agent_is_cmd "$c"; then echo "is_cmd '$c': yes"; else echo "is_cmd '$c': no"; fi
done
for wn in ai-1 ai-2 ai-3 dev shell; do
  if agent_is_window "$wn"; then echo "is_window '$wn': yes"; else echo "is_window '$wn': no"; fi
done
```

- [ ] **Step 5: Write the golden expected file**

Create `<scratchpad>/agent-golden.expected` with EXACTLY (these reproduce what the current committed `workspace.sh`, `wt-session.sh`, stashed `claude-resume.sh`, and `handoff-session.sh` emit):

```
windows: ai-1 ai-2
launch ai-1 cold: CLAUDE_CONFIG_DIR=/Users/alex/.claude-account1 claude
launch ai-2 cold: CLAUDE_CONFIG_DIR=/Users/alex/.claude-account2 claude
launch ai-1 resume: CLAUDE_CONFIG_DIR=/Users/alex/.claude-account1 claude "/resume myslug"
launch ai-2 resume: CLAUDE_CONFIG_DIR=/Users/alex/.claude-account2 claude "/resume myslug"
continue ai-1: CLAUDE_CONFIG_DIR=/Users/alex/.claude-account1 claude --continue
continue ai-2: CLAUDE_CONFIG_DIR=/Users/alex/.claude-account2 claude --continue
handoff keys: /handoff myslug
handoff file: /Users/alex/handoffs/myslug.md
wrapped ai-1 cold: zsh -ic 'CLAUDE_CONFIG_DIR=/Users/alex/.claude-account1 claude; exec zsh'
wrapped ai-2 cold: zsh -ic 'CLAUDE_CONFIG_DIR=/Users/alex/.claude-account2 claude; exec zsh'
is_cmd 'claude': yes
is_cmd 'node': yes
is_cmd '2.1.165': yes
is_cmd 'zsh': no
is_cmd 'nvim': no
is_cmd '': no
is_cmd 'tmux': no
is_window 'ai-1': yes
is_window 'ai-2': yes
is_window 'ai-3': no
is_window 'dev': no
is_window 'shell': no
```

- [ ] **Step 6: Run the golden diff (must be empty)**

Run (substitute `<scratchpad>`):
```bash
diff <(bash <scratchpad>/agent-golden.sh) <scratchpad>/agent-golden.expected && echo GOLDEN_OK
```
Expected: `GOLDEN_OK` with no diff lines. If it differs, fix the profile/loader — do not edit the expected file to match a wrong result.

- [ ] **Step 7: Commit**

```bash
git add scripts/lib/agent.sh scripts/agents.d/claude.sh
git commit -m "feat(agent): add adapter loader + claude profile

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Rewire workspace.sh

**Files:**
- Modify: `scripts/workspace.sh` (the ai-1/ai-2 `new-window` block, currently lines ~59-62; header comment lines ~5-6)

**Interfaces:**
- Consumes: `agent_windows`, `agent_launch_cmd` from Task 1.

- [ ] **Step 1: Source the loader**

In `scripts/workspace.sh`, immediately after the `set -Eeuo pipefail` line, add:

```sh
. "$(dirname "$0")/lib/agent.sh"
```

- [ ] **Step 2: Replace the hardcoded ai windows with a loop**

Replace this block:

```sh
  tm new-window  -t "$SESSION:" -n ai-1 -c "$PWD" \
    "zsh -ic 'CLAUDE_CONFIG_DIR=$HOME/.claude-account1 claude; exec zsh'"
  tm new-window  -t "$SESSION:" -n ai-2 -c "$PWD" \
    "zsh -ic 'CLAUDE_CONFIG_DIR=$HOME/.claude-account2 claude; exec zsh'"
```

with:

```sh
  for w in $(agent_windows); do
    inner="$(agent_launch_cmd "$w" "")"
    tm new-window  -t "$SESSION:" -n "$w" -c "$PWD" "zsh -ic '$inner; exec zsh'"
  done
```

- [ ] **Step 3: Update the header comment**

Change the header lines that read:

```sh
# current workspace, with four windows: dev, ai-1, ai-2, shell.
# ai-1 and ai-2 auto-run claude under separate CLAUDE_CONFIG_DIRs.
```

to:

```sh
# current workspace, with four windows: dev, ai-1, ai-2, shell. The ai-*
# windows auto-run the configured agent (see scripts/lib/agent.sh; default
# claude, one per CLAUDE_CONFIG_DIR).
```

- [ ] **Step 4: Syntax + shellcheck**

Run:
```bash
bash -n scripts/workspace.sh && echo SYNTAX_OK
command -v shellcheck >/dev/null && shellcheck -x scripts/workspace.sh || echo "shellcheck skipped"
```
Expected: `SYNTAX_OK`. (shellcheck may warn `SC1090` on the dynamic source — acceptable; add `# shellcheck source=/dev/null` above the source line if you want it clean.)

- [ ] **Step 5: Confirm the emitted string is unchanged**

The loop composes `zsh -ic '$inner; exec zsh'`; Task 1's golden `wrapped ai-1 cold` / `wrapped ai-2 cold` lines already proved `$inner` and the wrapper match the old literals. Confirm the diff of this file shows only the loop refactor and comment, no other change:
```bash
git diff scripts/workspace.sh
```
Expected: only the source line, the ai-window loop, and the comment differ.

- [ ] **Step 6: Commit**

```bash
git add scripts/workspace.sh
git commit -m "refactor(workspace): scaffold ai windows via agent adapter

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: Rewire wt-session.sh

**Files:**
- Modify: `scripts/wt-session.sh` (resume-arg parsing, the `claude_cmd()` helper, the ai-1/ai-2 `new-window` block, and the "resume slugs NOT applied" guard; header comment)

**Interfaces:**
- Consumes: `agent_windows`, `agent_launch_cmd` from Task 1.

- [ ] **Step 1: Source the loader**

After `set -e` near the top of `scripts/wt-session.sh`, add:

```sh
. "$(dirname "$0")/lib/agent.sh"
```

- [ ] **Step 2: Replace the RESUME_AI1/AI2 parsing with an array + lookup**

Replace this block:

```sh
# Resume slugs per ai window, from the optional "ai-N=<slug>" args above.
RESUME_AI1=""; RESUME_AI2=""
for a in "$@"; do
  case "$a" in
    ai-1=*) RESUME_AI1="${a#ai-1=}" ;;
    ai-2=*) RESUME_AI2="${a#ai-2=}" ;;
  esac
done
```

with:

```sh
# Resume slugs per ai window, from the optional "<window>=<slug>" args above.
RESUME_ARGS=("$@")
_slug_for() {  # $1 = window name -> prints its resume slug, or nothing
  local a
  for a in "${RESUME_ARGS[@]}"; do
    case "$a" in "$1="*) printf '%s' "${a#"$1"=}"; return ;; esac
  done
}
```

- [ ] **Step 3: Remove the claude_cmd helper**

Delete the entire `claude_cmd()` function:

```sh
claude_cmd() {
  local cfg="$1" slug="$2" inner
  if [ -n "$slug" ]; then
    inner="CLAUDE_CONFIG_DIR=$cfg claude \"/resume $slug\""
  else
    inner="CLAUDE_CONFIG_DIR=$cfg claude"
  fi
  printf "zsh -ic '%s; exec zsh'" "$inner"
}
```

(Its comment block above it, describing the quoting, goes too.)

- [ ] **Step 4: Replace the ai-window scaffolding with a loop**

Replace:

```sh
  "$TMUX_BIN" -L "$SOCK" new-window -t "$sess:" -n ai-1 -c "$path" \
    "$(claude_cmd "$HOME/.claude-account1" "$RESUME_AI1")"
  "$TMUX_BIN" -L "$SOCK" new-window -t "$sess:" -n ai-2 -c "$path" \
    "$(claude_cmd "$HOME/.claude-account2" "$RESUME_AI2")"
```

with:

```sh
  for w in $(agent_windows); do
    inner="$(agent_launch_cmd "$w" "$(_slug_for "$w")")"
    "$TMUX_BIN" -L "$SOCK" new-window -t "$sess:" -n "$w" -c "$path" \
      "zsh -ic '$inner; exec zsh'"
  done
```

- [ ] **Step 5: Generalize the "resume slugs NOT applied" guard**

Replace:

```sh
if [ "$scaffolded" = 0 ] && { [ -n "$RESUME_AI1" ] || [ -n "$RESUME_AI2" ]; }; then
  echo "wt-session: session '$sess' already existed — resume slugs (ai-1='$RESUME_AI1' ai-2='$RESUME_AI2') NOT applied" >&2
  exit 3
fi
```

with:

```sh
if [ "$scaffolded" = 0 ] && [ "${#RESUME_ARGS[@]}" -gt 0 ]; then
  echo "wt-session: session '$sess' already existed — resume slugs (${RESUME_ARGS[*]}) NOT applied" >&2
  exit 3
fi
```

- [ ] **Step 6: Update the header comment**

Change the header lines describing the resume args:

```sh
# Optional extra args carry a Claude context handoff into the new session:
#   wt-session.sh <path> ai-1=<slug> ai-2=<slug>
# A window named on the left boots `claude "/resume <slug>"` instead of cold,
# loading the handoff at ~/handoffs/<slug>.md (see wt-rehome.sh / handoff.md).
```

to:

```sh
# Optional extra args carry an agent context handoff into the new session:
#   wt-session.sh <path> ai-1=<slug> ai-2=<slug>
# A window named on the left boots the agent resumed from <slug> instead of
# cold, loading the handoff at ~/handoffs/<slug>.md (see scripts/lib/agent.sh,
# wt-rehome.sh / handoff.md).
```

- [ ] **Step 7: Syntax + shellcheck**

Run:
```bash
bash -n scripts/wt-session.sh && echo SYNTAX_OK
command -v shellcheck >/dev/null && shellcheck -x scripts/wt-session.sh || echo "shellcheck skipped"
```
Expected: `SYNTAX_OK`.

- [ ] **Step 8: Verify slug lookup + empty-args behavior**

Run this isolated check (proves `_slug_for` and the guard condition without touching tmux):
```bash
bash -c '
RESUME_ARGS=(ai-1=foo ai-2=bar)
_slug_for(){ local a; for a in "${RESUME_ARGS[@]}"; do case "$a" in "$1="*) printf "%s" "${a#"$1"=}"; return;; esac; done; }
echo "ai-1=$(_slug_for ai-1) ai-2=$(_slug_for ai-2) miss=[$(_slug_for ai-9)] count=${#RESUME_ARGS[@]}"
RESUME_ARGS=(); echo "empty count=${#RESUME_ARGS[@]} loop:$(for a in "${RESUME_ARGS[@]}"; do echo x; done)"
'
```
Expected: `ai-1=foo ai-2=bar miss=[] count=2` then `empty count=0 loop:` (no error).

- [ ] **Step 9: Commit**

```bash
git add scripts/wt-session.sh
git commit -m "refactor(wt-session): scaffold+resume ai windows via agent adapter

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: Rewire handoff-session.sh

**Files:**
- Modify: `scripts/handoff-session.sh` (remove `_is_claude_cmd` and its own `HANDOFF_DIR` default; swap in `agent_is_cmd`, `agent_is_window`, `agent_handoff_keys`, `agent_handoff_file`; header comment)

**Interfaces:**
- Consumes: `agent_is_cmd`, `agent_is_window`, `agent_handoff_keys`, `agent_handoff_file`, and the loader-set `HANDOFF_DIR`.

- [ ] **Step 1: Source the loader and drop the local HANDOFF_DIR default**

Replace:

```sh
HANDOFF_DIR="${HANDOFF_DIR:-$HOME/handoffs}"
WSG_SOCK="${WSG_SOCK:-wsg}"
DEFAULT_TIMEOUT=180
```

with:

```sh
. "$(dirname "$0")/lib/agent.sh"     # sets HANDOFF_DIR; provides agent_* helpers
WSG_SOCK="${WSG_SOCK:-wsg}"
DEFAULT_TIMEOUT=180
```

- [ ] **Step 2: Remove the local `_is_claude_cmd`**

Delete this function and its comment:

```sh
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
```

- [ ] **Step 3: Swap the pane gate and command detection in `cmd_fire`**

Replace:

```sh
        case "$wname" in ai-*) ;; *) continue ;; esac
        _is_claude_cmd "$cmd" || continue
```

with:

```sh
        agent_is_window "$wname" || continue
        agent_is_cmd "$cmd" || continue
```

- [ ] **Step 4: Route the slug-file path and handoff keys through the adapter**

In `cmd_fire`, replace the noclobber reservation line:

```sh
        until (set -o noclobber; : > "$HANDOFF_DIR/$slug.md") 2>/dev/null; do
```
with:
```sh
        until (set -o noclobber; : > "$(agent_handoff_file "$slug")") 2>/dev/null; do
```

and replace the send-keys trigger:

```sh
        tmux -L "$WSG_SOCK" send-keys -t "$pid" -l "/handoff $slug"
```
with:
```sh
        tmux -L "$WSG_SOCK" send-keys -t "$pid" -l "$(agent_handoff_keys "$slug")"
```

In `cmd_await`, replace:
```sh
      _settled "$HANDOFF_DIR/$slug.md" || { all=0; break; }
```
with:
```sh
      _settled "$(agent_handoff_file "$slug")" || { all=0; break; }
```

In `cmd_check`, replace:
```sh
  for e in "$@"; do _settled "$HANDOFF_DIR/${e##*|}.md" || return 1; done
```
with:
```sh
  for e in "$@"; do _settled "$(agent_handoff_file "${e##*|}")" || return 1; done
```

- [ ] **Step 5: Update the header comment**

Change the opening comment block's first lines:

```sh
# handoff-session.sh — save the Claude context of a wsg tmux session via the
# `/handoff` command before the session is torn down. Covers both Claude
# instances (ai-1 = account1, ai-2 = account2); `/handoff` is symlinked into
# both configs and writes to the shared ~/handoffs/, so one trigger fits all.
```

to:

```sh
# handoff-session.sh — save the agent context of a wsg tmux session before the
# session is torn down, by sending the agent's handoff command into each ai
# window's pane. Agent specifics (which windows, the trigger keys, the output
# file) come from scripts/lib/agent.sh; the default agent (claude) writes to
# the shared ~/handoffs/ via `/handoff <slug>`.
```

- [ ] **Step 6: Syntax + shellcheck**

Run:
```bash
bash -n scripts/handoff-session.sh && echo SYNTAX_OK
command -v shellcheck >/dev/null && shellcheck -x scripts/handoff-session.sh || echo "shellcheck skipped"
```
Expected: `SYNTAX_OK`.

- [ ] **Step 7: Re-run the golden harness (detection + paths unchanged)**

The behaviors handoff-session relies on (`agent_is_cmd`, `agent_is_window`, `agent_handoff_file`, `agent_handoff_keys`) are all covered by Task 1's harness. Re-run it to confirm nothing regressed:
```bash
diff <(bash <scratchpad>/agent-golden.sh) <scratchpad>/agent-golden.expected && echo GOLDEN_OK
```
Expected: `GOLDEN_OK`.

- [ ] **Step 8: Commit**

```bash
git add scripts/handoff-session.sh
git commit -m "refactor(handoff-session): route agent detection + handoff via adapter

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: Wording cleanup, live smoke run, finish

**Files:**
- Modify (wording only, where Claude-specific text now misleads): `scripts/wt-rehome.sh`, `scripts/wt-prune.sh` comments/echo strings that say "Claude" for the generic context step. Leave logic untouched.
- Modify: `~/.local/share/dotfiles-stash/tmux-resurrect/RESTORE.md` (note claude-resume.sh should adopt `agent_continue_cmd` when restored). This file is outside the repo — edit in place, it is not committed.

**Interfaces:**
- Consumes: the fully rewired scripts from Tasks 2-4.

- [ ] **Step 1: Soften Claude-specific wording in wt-rehome.sh / wt-prune.sh**

Optional and cosmetic. In `scripts/wt-rehome.sh` and `scripts/wt-prune.sh`, where user-facing echoes say "Claude context" for the generic save step, change to "agent context". Do NOT change any variable names, control flow, or the `~/.scripts/handoff-session.sh` / `wt-session.sh` calls. Example in wt-rehome.sh:
```sh
    echo "saving Claude context for '$OLD_SESS' (/handoff)..."
```
→
```sh
    echo "saving agent context for '$OLD_SESS' (/handoff)..."
```
Skip any line where "Claude" is still accurate. If you make no changes here, that is fine — proceed.

- [ ] **Step 2: Syntax-check any files touched in Step 1**

Run (only for files you edited):
```bash
for f in scripts/wt-rehome.sh scripts/wt-prune.sh; do bash -n "$f" && echo "OK $f"; done
```
Expected: `OK` for each.

- [ ] **Step 3: Live smoke run — scaffold a throwaway session via the adapter**

Create a throwaway git repo and drive `wt-session.sh` against it to confirm the adapter path scaffolds `ai-1`/`ai-2` correctly. This uses the real `wsg` tmux socket but a disposable session name.

```bash
TMP="$(mktemp -d)"; git -C "$TMP" init -q; git -C "$TMP" commit -q --allow-empty -m init
~/.scripts/wt-session.sh "$TMP"
SESS="$(basename "$TMP")"
tmux -L wsg list-windows -t "$SESS" -F '#{window_name}'
tmux -L wsg list-panes -s -t "$SESS" -F '#{window_name} #{pane_start_command}'
```
Expected: windows include `shell`, `dev`, `ai-1`, `ai-2`; the `ai-1`/`ai-2` panes' start commands contain `CLAUDE_CONFIG_DIR=/Users/alex/.claude-account1 claude` and `...account2 claude` respectively, wrapped in `zsh -ic '...; exec zsh'`.

- [ ] **Step 4: Tear down the smoke session**

```bash
tmux -L wsg kill-session -t "$SESS" 2>/dev/null || true
rm -rf "$TMP"
echo "cleaned up $SESS"
```
Expected: `cleaned up <name>`.

- [ ] **Step 5: Note the resurrect stash follow-up**

Append to `~/.local/share/dotfiles-stash/tmux-resurrect/RESTORE.md` a line under the restore steps: when restored, update `claude-resume.sh` to `source ~/.scripts/lib/agent.sh` and `exec ${SHELL:-sh} -c "$(agent_continue_cmd "$win")"` instead of the hardcoded `case`/`claude --continue`.

- [ ] **Step 6: Commit any repo wording changes**

Only if Step 1 changed tracked files:
```bash
git add scripts/wt-rehome.sh scripts/wt-prune.sh
git commit -m "docs(scripts): agent-neutral wording for context handoff

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

- [ ] **Step 7: Final review of the whole branch**

```bash
git log --oneline master..agent-adapter
git diff master..agent-adapter --stat
```
Expected: commits for the spec, adapter+profile, and each rewired script; the diffstat touches only `scripts/lib/agent.sh`, `scripts/agents.d/claude.sh`, `scripts/workspace.sh`, `scripts/wt-session.sh`, `scripts/handoff-session.sh`, optional wt-rehome/wt-prune wording, and the `docs/superpowers/` spec+plan.

---

## Self-Review

**Spec coverage:**
- Loader + profile → Task 1. ✓
- Six-function contract + `agent_is_window` → Task 1 (golden harness exercises all). ✓
- `workspace.sh` loop → Task 2. ✓
- `wt-session.sh` RESUME_ARGS/_slug_for/loop/exit-3 → Task 3. ✓
- `handoff-session.sh` four swaps + HANDOFF_DIR ownership → Task 4. ✓
- `wt-rehome.sh`/`wt-prune.sh` functionally untouched, wording only → Task 5. ✓
- Golden-output diff verification → Tasks 1, 4. ✓
- Live smoke run → Task 5. ✓
- `claude-resume.sh` stash untouched, RESTORE.md note → Task 5. ✓
- opencode out of scope → not implemented (spec informational section only). ✓

**Placeholder scan:** No TBD/TODO; every code step shows full code; every command shows expected output. ✓

**Type/name consistency:** `agent_windows`, `agent_launch_cmd`, `agent_continue_cmd`, `agent_handoff_keys`, `agent_handoff_file`, `agent_is_cmd`, `agent_is_window`, `_agent_env`, `_slug_for`, `RESUME_ARGS` used identically across the loader, profile, and all call sites. ✓
