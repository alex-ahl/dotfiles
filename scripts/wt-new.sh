#!/usr/bin/env bash
# wt-new — create a worktree + wsg session for a NEW branch off the LATEST
# default branch. Bound to `prefix + b` (see tmux.conf).
#
#   wt-new <repo-dir> <branch>
#
# Unlike a bare `wt switch -c`, it bases the branch off origin/<default> (freshest
# remote tip) without checking out or mutating the local default branch. Fetch is
# best-effort: offline / no remote falls back to the local default branch.
set -Eeuo pipefail

DIR="${1:-}"; BRANCH="${2:-}"
if [ -z "$DIR" ] || [ -z "$BRANCH" ]; then echo "usage: wt-new <repo-dir> <branch>" >&2; exit 1; fi

# Default branch (main/master) via origin/HEAD, with fallbacks.
DEFAULT="$(git -C "$DIR" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)"
DEFAULT="${DEFAULT#origin/}"
if [ -z "$DEFAULT" ]; then
  git -C "$DIR" remote set-head origin -a >/dev/null 2>&1 || true
  DEFAULT="$(git -C "$DIR" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)"
  DEFAULT="${DEFAULT#origin/}"
fi
[ -z "$DEFAULT" ] && for b in main master; do
  git -C "$DIR" show-ref --verify --quiet "refs/heads/$b" && { DEFAULT="$b"; break; }
done
[ -z "$DEFAULT" ] && { echo "could not determine default branch for '$DIR'" >&2; exit 1; }

# Base off origin/<default> when the fetch succeeds; else local <default>.
BASE="$DEFAULT"
if git -C "$DIR" fetch origin "$DEFAULT" --quiet 2>/dev/null \
   && git -C "$DIR" show-ref --verify --quiet "refs/remotes/origin/$DEFAULT"; then
  BASE="origin/$DEFAULT"
else
  echo "warning: couldn't fetch origin/$DEFAULT — basing off local '$DEFAULT'." >&2
fi

echo "creating worktree '$BRANCH' off '$BASE'..."
wt -y -C "$DIR" switch -c "$BRANCH" --base "$BASE"
