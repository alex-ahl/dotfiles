#!/usr/bin/env bash
# List worktrees in current repo whose branch has no live upstream.
# Run from any worktree/subdir inside a git repo.

set -u

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
  && ! git rev-parse --is-inside-git-dir >/dev/null 2>&1; then
  echo "not inside a git repo" >&2
  exit 1
fi

echo "fetching + pruning remote refs..."
git fetch -p --quiet 2>/dev/null || true

echo
printf "%-55s %-35s %s\n" "WORKTREE" "BRANCH" "UPSTREAM STATUS"
printf "%-55s %-35s %s\n" "--------" "------" "---------------"

git worktree list --porcelain \
  | awk '/^worktree /{print $2}' \
  | while read -r WT; do
      [[ -d "$WT/.git" || -f "$WT/.git" ]] || continue

      BRANCH="$(git -C "$WT" symbolic-ref --short HEAD 2>/dev/null || echo "DETACHED")"

      if [[ "$BRANCH" == "DETACHED" ]]; then
        STATUS="detached HEAD"
      else
        UPSTREAM="$(git -C "$WT" rev-parse --abbrev-ref --symbolic-full-name "@{u}" 2>/dev/null || true)"
        TRACK="$(git -C "$WT" for-each-ref --format='%(upstream:track)' "refs/heads/$BRANCH")"
        if [[ -z "$UPSTREAM" ]]; then
          STATUS="NO UPSTREAM (never pushed?)"
        elif [[ "$TRACK" == "[gone]" ]]; then
          STATUS="GONE (remote branch deleted) -> $UPSTREAM"
        else
          STATUS="ok -> $UPSTREAM"
        fi
      fi

      printf "%-55s %-35s %s\n" "$WT" "$BRANCH" "$STATUS"
    done
