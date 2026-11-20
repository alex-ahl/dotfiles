#!/usr/bin/env bash
# wt-land — land this worktree's branch on the default branch without a PR, then
# clean up, or keep the worktree for a long-lived branch. Bound to `prefix + M`
# (see tmux.conf).
#
#   1. fast-forward the local default branch to origin, so the push below lands
#   2. `wt merge --no-commit`: rebase onto it, fast-forward it, remove the
#      worktree + branch. --no-commit keeps your commits as they are.
#      If the rebase conflicts, merge the default branch in instead: each
#      conflict then comes up once, against both final versions, not once per
#      replayed commit. Resolve, commit, run again; it lands without a rebase.
#   3. push the default branch; unless kept, switch to its session, kill this one
#
# Refuses a dirty worktree: --no-commit would leave the changes behind.
set -Eeuo pipefail

git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
  || { echo "not inside a git worktree" >&2; exit 1; }
WT_PATH="$(git rev-parse --show-toplevel)"
BRANCH="$(git symbolic-ref --quiet --short HEAD || true)"
DEFAULT="$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##')"

[ -z "$DEFAULT" ] && { echo "could not determine the default branch (origin/HEAD)" >&2; exit 1; }
[ -z "$BRANCH" ] && { echo "detached HEAD — nothing to land" >&2; exit 1; }
[ "$BRANCH" = "$DEFAULT" ] && { echo "this is the '$DEFAULT' worktree — nothing to land" >&2; exit 1; }
[ -n "$(git status --porcelain)" ] && { echo "uncommitted changes — commit or stash them first" >&2; exit 1; }

DEFAULT_WT="$(git worktree list --porcelain \
  | awk -v b="refs/heads/$DEFAULT" '/^worktree /{p=substr($0,10)} $0=="branch "b{print p; exit}')"
[ -z "$DEFAULT_WT" ] && { echo "no worktree checks out '$DEFAULT'" >&2; exit 1; }

echo "fetching origin..."
git fetch origin "$DEFAULT" --quiet
git -C "$DEFAULT_WT" merge --ff-only --quiet "origin/$DEFAULT" \
  || { echo "can't fast-forward '$DEFAULT' to origin/$DEFAULT (diverged, or its changes clash) — fix that first" >&2; exit 1; }

echo
BEHIND="$(git rev-list --count "HEAD..$DEFAULT")"
echo "landing '$BRANCH' on '$DEFAULT' (behind it by $BEHIND):"
git log --oneline "$DEFAULT..HEAD"
printf "\nPush to origin/%s?\n  y  land, then remove this worktree, branch and session\n  k  land, keep them (long-lived branch)\n[y/k/N] " "$DEFAULT"
IFS= read -r answer
case "$answer" in
  [yY]*) KEEP=0 ;;
  [kK]*) KEEP=1 ;;
  *) echo "cancelled"; exit 0 ;;
esac
[ "$KEEP" = 1 ] && [ -z "$(git rev-list "$DEFAULT..HEAD")" ] && { echo "nothing new to land"; exit 0; }

SESSION="$(tmux -L wsg list-sessions -F '#{session_name}|#{session_path}' 2>/dev/null \
  | awk -F'|' -v p="$WT_PATH" '$2==p {print $1; exit}')"

# A branch that already has the default branch merged in must not be rebased:
# the rebase would drop that merge and replay every commit again.
land() {
  local flags=(--no-commit)
  [ "$KEEP" = 1 ] && flags+=(--no-remove)
  git merge-base --is-ancestor "$DEFAULT" HEAD && flags+=(--no-rebase)
  wt merge "${flags[@]}"
}

rebase_in_progress() {
  [ -d "$(git rev-parse --git-path rebase-merge)" ] || [ -d "$(git rev-parse --git-path rebase-apply)" ]
}

if ! land; then
  rebase_in_progress || exit 1
  echo
  echo "rebase conflicts — merging '$DEFAULT' in instead, so each conflict comes up once"
  git rebase --abort
  # --no-ff: the global merge.ff=only would refuse this merge.
  if ! git merge --no-ff --no-edit "$DEFAULT"; then
    echo
    echo "resolve the conflicts here, \`git commit\`, then press prefix + M again"
    exit 1
  fi
  land
fi

git -C "$DEFAULT_WT" push origin "$DEFAULT"

if [ "$KEEP" = 1 ]; then
  echo "done — '$BRANCH' landed on origin/$DEFAULT; worktree kept"
  exit 0
fi
cd "$DEFAULT_WT"   # the worktree dir is being removed
~/.scripts/wt-session.sh "$DEFAULT_WT"
[ -n "$SESSION" ] && tmux -L wsg kill-session -t "$SESSION"
echo "done — '$BRANCH' landed on origin/$DEFAULT"
