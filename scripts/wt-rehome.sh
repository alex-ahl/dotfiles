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
  echo "note: no merged PR detected for '$OLD_BRANCH'." >&2
  printf "Branch '%s' off the CURRENT HEAD and keep this worktree/session intact? [y/N] " "$NEW" >&2
  IFS= read -r ans
  case "$ans" in [yY] | [yY][eE][sS]) ;; *) echo "aborted." >&2; exit 1 ;; esac
fi

# In-progress work to carry? Detect now; actually stash only after each path's
# abort-able preflight, so an early abort never leaves changes stranded.
STASHED=0
[ -n "$(git -C "$OLD_PATH" status --porcelain)" ] && STASHED=1
do_stash() { [ "$STASHED" = 1 ] && git -C "$OLD_PATH" stash push -u -m "wt-rehome: $OLD_BRANCH -> $NEW" >/dev/null; }

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
  ~/.scripts/wt-session.sh "$NEW_PATH"

  if [ "$STASHED" = 1 ] && ! git -C "$NEW_PATH" stash pop; then
    {
      echo
      echo "!! stash pop hit conflicts in $NEW_PATH"
      echo "   The old worktree '$OLD_BRANCH' and its session are left intact as a fallback."
      echo "   Resolve in the new '$NEW' session, then: wt remove $OLD_BRANCH -f"
    } >&2
    exit 1
  fi

  echo "removing old worktree '$OLD_BRANCH'..."
  wt -C "$NEW_PATH" remove "$OLD_BRANCH" -f -y
  OLD_SESS="$(tmux -L wsg list-sessions -F '#{session_name}|#{session_path}' 2>/dev/null \
    | awk -F'|' -v p="$OLD_PATH" '$2==p {print $1; exit}')"
  [ -n "$OLD_SESS" ] && tmux -L wsg kill-session -t "$OLD_SESS" 2>/dev/null || true
  echo "done — rehomed '$OLD_BRANCH' -> '$NEW' (off latest $DEFAULT); old worktree removed."
else
  # === NOT MERGED: fork off the current HEAD, copy changes, keep old ===========
  do_stash
  echo "creating worktree '$NEW' off the current HEAD of '$OLD_BRANCH'..."
  wt -C "$OLD_PATH" switch -c "$NEW" --base @ --no-hooks -y
  NEW_PATH="$(worktree_for "$NEW")"
  [ -z "$NEW_PATH" ] && { echo "could not locate new worktree path for '$NEW'" >&2; exit 1; }
  cd "$NEW_PATH"
  wt -C "$NEW_PATH" step copy-ignored --from "$OLD_BRANCH" --to "$NEW" --force >/dev/null 2>&1 || true
  ~/.scripts/wt-session.sh "$NEW_PATH"

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
  echo "done — forked '$OLD_BRANCH' -> '$NEW' (off current HEAD); old worktree/session kept."
fi
