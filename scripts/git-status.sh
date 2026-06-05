#!/usr/bin/env bash
# Print git branch (+ worktree name) for the tmux status bar.
# Arg $1 = pane cwd. Silent (empty) when not in a git repo.
# Tuned for a bare-repo-with-worktrees layout: every checkout is a
# linked worktree, so show the worktree name only when it differs
# from the branch (dirs are usually named after their branch).
set -e
cd "${1:-$PWD}" 2>/dev/null || exit 0

branch=$(git branch --show-current 2>/dev/null) || exit 0

# Linked worktree (incl. every checkout of a bare repo): its own
# git-dir differs from the shared common dir. Normal repos: equal.
gitdir=$(git rev-parse --git-dir 2>/dev/null)
common=$(git rev-parse --git-common-dir 2>/dev/null)
in_wt=0
[ -n "$gitdir" ] && [ "$gitdir" != "$common" ] && in_wt=1

wt=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)")

#  = nf powerline branch glyph (needs the Nerd Font).
if [ -n "$branch" ]; then
  out=" $branch"
  # Show worktree name only in a real worktree where it adds info.
  [ "$in_wt" = 1 ] && [ "$wt" != "$branch" ] && out="$out @$wt"
else
  # Detached HEAD: worktree name + short sha.
  out=" $wt @$(git rev-parse --short HEAD 2>/dev/null)"
fi

printf '%s' "$out"
