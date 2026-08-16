#!/usr/bin/env bash
# wt-rehome — start a fresh worktree + wsg tmux session from the current one,
# carrying your in-progress work along. Behaviour depends on whether the current
# branch's PR is merged:
#
#   MERGED      → new worktree branches off the latest default branch; your
#                 uncommitted + untracked changes MOVE to it; the old worktree
#                 and its tmux session are torn down.
#   NOT MERGED  → (after confirmation) new worktree branches off the CURRENT
#                 HEAD, so it carries the commits too; your changes are COPIED
#                 to it; the old worktree and session are KEPT intact.
#
#   wt-rehome <new-worktree-name>
#
# Run from inside the worktree you want to move on from. Gitignored files
# (e.g. .env, caches) are copied across via `wt step copy-ignored` in both modes.

set -Eeuo pipefail

NEW="${1:-}"
[ -z "$NEW" ] && { echo "usage: wt-rehome <new-worktree-name>" >&2; exit 1; }


# --- Validate the source worktree ---------------------------------------------
git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
  || { echo "not inside a git worktree" >&2; exit 1; }
OLD_PATH="$(git rev-parse --show-toplevel)"
OLD_BRANCH="$(git -C "$OLD_PATH" symbolic-ref --quiet --short HEAD || true)"
[ -z "$OLD_BRANCH" ] && { echo "current worktree is in detached HEAD — refusing to rehome" >&2; exit 1; }

[ "$NEW" = "$OLD_BRANCH" ] && { echo "new name matches the current branch — nothing to do" >&2; exit 1; }
git show-ref --verify --quiet "refs/heads/$NEW" \
  && { echo "branch '$NEW' already exists — pick another name" >&2; exit 1; }

worktree_for() {  # branch -> worktree path ("" if none)
  git worktree list --porcelain \
    | awk -v b="refs/heads/$1" '/^worktree /{p=substr($0,10)} $0=="branch "b{print p; exit}'
}

# --- Determine the default branch (main vs master) ----------------------------
DEFAULT="$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##')"
if [ -z "$DEFAULT" ]; then
  git remote set-head origin -a >/dev/null 2>&1 || true
  DEFAULT="$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##')"
fi
[ -z "$DEFAULT" ] && for b in main master; do
  git show-ref --verify --quiet "refs/remotes/origin/$b" && { DEFAULT="$b"; break; }
done
[ -z "$DEFAULT" ] && { echo "could not determine default branch (origin/HEAD)" >&2; exit 1; }
[ "$OLD_BRANCH" = "$DEFAULT" ] && { echo "refusing to rehome the default-branch ('$DEFAULT') worktree" >&2; exit 1; }

# --- Is the current branch's PR merged? ---------------------------------------
# Accurate for squash-merges, unlike a local origin/<default>..HEAD check.
# No PR / no gh / non-GitHub repo => can't verify => treated as "not merged".
MERGED=0
if command -v gh >/dev/null 2>&1; then
  [ "$(gh pr view "$OLD_BRANCH" --json state --jq .state 2>/dev/null || true)" = "MERGED" ] && MERGED=1
fi

if [ "$MERGED" = 0 ]; then
  # Not merged → non-destructive fork: keep the old worktree + session, just
  # branch a new one off the current HEAD. No confirmation needed.
  echo "no merged PR for '$OLD_BRANCH' — forking '$NEW' off the current HEAD; old worktree/session kept."
fi

# In-progress work to carry? Detect now; actually stash only after each path's
# abort-able preflight, so an early abort never leaves changes stranded.
STASHED=0
[ -n "$(git -C "$OLD_PATH" status --porcelain)" ] && STASHED=1
do_stash() { [ "$STASHED" = 1 ] && git -C "$OLD_PATH" stash push -u -m "wt-rehome: $OLD_BRANCH -> $NEW" >/dev/null; return 0; }

# The wsg tmux session sitting on the old worktree (empty if none / no server).
OLD_SESS="$(tmux -L wsg list-sessions -F '#{session_name}|#{session_path}' 2>/dev/null \
  | awk -F'|' -v p="$OLD_PATH" '$2==p {print $1; exit}')"

# Carry the old session's agent context into the new one? Ask up front (default
# yes) when there's a session to save and we're on a TTY; non-interactive runs
# default to carrying.
HANDOFF=1
if [ -n "$OLD_SESS" ] && [ -t 0 ]; then
  printf "Carry agent context to '%s'? [Y/n] " "$NEW"
  IFS= read -r _hc
  case "$_hc" in [nN]*) HANDOFF=0 ;; esac
fi

# Save the old session's agent context via /handoff and echo resume args
# ("<window>=<slug>"...) for wt-session.sh, so the new session's ai windows boot
# resumed. Returns non-zero if a fired handoff never settled in time (the caller
# decides whether that's fatal). Echoes nothing when there are no agent panes.
save_context_map() {  # $1 = old session name
  local sess="$1" lines pairs wname pid slug args=""
  lines="$(~/.scripts/handoff-session.sh fire "$sess" 2>/dev/null)"
  [ -z "$lines" ] && return 0
  pairs="$(printf '%s\n' "$lines" | tr '\n' ' ')"
  # shellcheck disable=SC2086
  ~/.scripts/handoff-session.sh await 180 $pairs || return 1
  while IFS='|' read -r wname pid slug; do
    [ -n "$wname" ] && args="$args $wname=$slug"
  done <<EOF
$lines
EOF
  printf '%s' "$args"
}

if [ "$MERGED" = 1 ]; then
  # === MERGED: rehome off the latest default branch, then tear down old ========
  echo "fetching origin..."
  git -C "$OLD_PATH" fetch origin --prune --quiet
  MAIN_WT="$(worktree_for "$DEFAULT")"
  [ -z "$MAIN_WT" ] && { echo "no worktree checks out '$DEFAULT'; aborting" >&2; exit 1; }
  if ! git -C "$MAIN_WT" merge --ff-only "origin/$DEFAULT" >/dev/null 2>&1; then
    echo "cannot fast-forward '$DEFAULT' to origin/$DEFAULT (dirty or diverged) — resolve it first; aborting." >&2
    exit 1
  fi
  do_stash   # preflight passed — safe to stash now

  echo "creating worktree '$NEW' off latest '$DEFAULT'..."
  wt -C "$OLD_PATH" switch -c "$NEW" --no-hooks -y
  NEW_PATH="$(worktree_for "$NEW")"
  [ -z "$NEW_PATH" ] && { echo "could not locate new worktree path for '$NEW'" >&2; exit 1; }
  cd "$NEW_PATH"   # old worktree dir is removed below; keep a valid cwd
  wt -C "$NEW_PATH" step copy-ignored --from "$OLD_BRANCH" --to "$NEW" --force >/dev/null 2>&1 || true

  # Save the old session's agent context BEFORE bringing up the new session, so
  # its ai windows can resume it. If the handoff can't be saved we keep the old
  # worktree + session intact and bring the new one up cold (below).
  RESUME_ARGS=""; SAVE_OK=1
  if [ "$HANDOFF" = 1 ] && [ -n "$OLD_SESS" ]; then
    echo "saving agent context for '$OLD_SESS' (/handoff)..."
    RESUME_ARGS="$(save_context_map "$OLD_SESS")" || SAVE_OK=0
  fi

  # shellcheck disable=SC2086
  # If we saved context but the new session already existed, wt-session exits
  # non-zero (resume slugs not applied). Treat that like a failed save so the
  # old session/worktree is kept intact below rather than torn down.
  if ! ~/.scripts/wt-session.sh "$NEW_PATH" $RESUME_ARGS && [ -n "$RESUME_ARGS" ]; then
    SAVE_OK=0
  fi

  if [ "$STASHED" = 1 ] && ! git -C "$NEW_PATH" stash pop; then
    {
      echo
      echo "!! stash pop hit conflicts in $NEW_PATH"
      echo "   The old worktree '$OLD_BRANCH' and its session are left intact as a fallback."
      echo "   Resolve in the new '$NEW' session, then: wt remove $OLD_BRANCH -f"
    } >&2
    exit 1
  fi

  if [ "$SAVE_OK" = 0 ]; then
    echo "warning: /handoff didn't finish for '$OLD_SESS' — keeping the old worktree + session intact." >&2
    echo "done — created '$NEW' off latest $DEFAULT (cold); old '$OLD_BRANCH' kept (context not saved)."
    exit 0
  fi

  echo "removing old worktree '$OLD_BRANCH'..."
  wt -C "$NEW_PATH" remove "$OLD_BRANCH" -f -y
  [ -n "$OLD_SESS" ] && tmux -L wsg kill-session -t "$OLD_SESS" 2>/dev/null || true
  echo "done — rehomed '$OLD_BRANCH' -> '$NEW' (off latest $DEFAULT); context carried; old worktree removed."
else
  # === NOT MERGED: fork off the current HEAD, copy changes, keep old ===========
  do_stash
  echo "creating worktree '$NEW' off the current HEAD of '$OLD_BRANCH'..."
  wt -C "$OLD_PATH" switch -c "$NEW" --base @ --no-hooks -y
  NEW_PATH="$(worktree_for "$NEW")"
  [ -z "$NEW_PATH" ] && { echo "could not locate new worktree path for '$NEW'" >&2; exit 1; }
  cd "$NEW_PATH"
  wt -C "$NEW_PATH" step copy-ignored --from "$OLD_BRANCH" --to "$NEW" --force >/dev/null 2>&1 || true

  # Carry the old session's agent context into the new one. The old session is
  # kept here, so a failed save is non-fatal — the new session just starts cold.
  RESUME_ARGS=""
  if [ "$HANDOFF" = 1 ] && [ -n "$OLD_SESS" ]; then
    echo "saving agent context for '$OLD_SESS' (/handoff)..."
    RESUME_ARGS="$(save_context_map "$OLD_SESS")" \
      || { echo "warning: /handoff didn't finish — new session will start cold." >&2; RESUME_ARGS=""; }
  fi

  # shellcheck disable=SC2086
  ~/.scripts/wt-session.sh "$NEW_PATH" $RESUME_ARGS

  if [ "$STASHED" = 1 ]; then
    # New shares old's HEAD, so the stash applies cleanly. apply (don't drop) in
    # the new worktree, then pop in the old to restore it — both end up with the
    # changes and the old worktree is left exactly as it was.
    apply_conflict=0
    git -C "$NEW_PATH" stash apply >/dev/null 2>&1 || apply_conflict=1
    git -C "$OLD_PATH" stash pop >/dev/null 2>&1 || true
    if [ "$apply_conflict" = 1 ]; then
      echo "warning: changes applied with conflicts in '$NEW' — resolve them there. Old worktree untouched." >&2
    fi
  fi
  echo "done — forked '$OLD_BRANCH' -> '$NEW' (off current HEAD); context carried; old worktree/session kept."
fi
