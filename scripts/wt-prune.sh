#!/usr/bin/env bash
# wt-prune — sweep all wsg tmux sessions and clean up the finished ones.
#
# A session qualifies for pruning when its git branch is either:
#   • merged   — the branch has a MERGED PR (via `gh pr view`), or
#   • gone      — its upstream was deleted on the remote (git '[gone]').
#
# For a linked worktree: the worktree is removed AND the session killed.
# For a regular (single-worktree) repo: it's switched back to the default
# branch, the merged local branch is deleted, and the session killed.
#
# Always skipped: the default branch, dirty worktrees (uncommitted/untracked),
# and the session you're currently attached to.
#
#   wt-prune [-y]      -y / --yes : skip the confirmation prompt
#
# Prints a plan and asks for confirmation (unless -y) before changing anything.

set -Eeuo pipefail

YES=0
HANDOFF=1
for arg in "$@"; do
  case "$arg" in
    -y | --yes) YES=1 ;;
    --no-handoff) HANDOFF=0 ;;
    *) echo "usage: wt-prune [-y] [--no-handoff]" >&2; exit 1 ;;
  esac
done

command -v tmux >/dev/null || { echo "tmux not found" >&2; exit 1; }
tmux -L wsg list-sessions >/dev/null 2>&1 || { echo "no wsg tmux server running — nothing to do."; exit 0; }

# Session we're attached to (never prune the one we're sitting in).
CUR=""
[ -n "${TMUX:-}" ] && CUR="$(tmux -L wsg display-message -p '#S' 2>/dev/null || true)"

default_branch() {  # <path> -> default branch name (main/master)
  local p="$1" d
  d="$(git -C "$p" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##')"
  if [ -z "$d" ]; then
    git -C "$p" remote set-head origin -a >/dev/null 2>&1 || true
    d="$(git -C "$p" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##')"
  fi
  [ -z "$d" ] && for b in main master; do
    git -C "$p" show-ref --verify --quiet "refs/remotes/origin/$b" && { d="$b"; break; }
  done
  printf '%s' "$d"
}

worktree_for() {  # <path-in-repo> <branch> -> that branch's worktree path
  git -C "$1" worktree list --porcelain \
    | awk -v b="refs/heads/$2" '/^worktree /{p=substr($0,10)} $0=="branch "b{print p; exit}'
}

fetched=""                                   # common-dirs already fetched this run
P_SESS=(); P_PATH=(); P_BRANCH=(); P_DEF=(); P_KIND=(); P_REASON=(); P_CTX=()   # the prune plan
SKIPS=()

while IFS='|' read -r sess spath; do
  [ -z "$sess" ] && continue

  # Orphan: the session's directory no longer exists (worktree already removed
  # out from under it). Plan to just kill the dead session.
  if [ ! -e "$spath" ]; then
    if [ -n "$CUR" ] && [ "$sess" = "$CUR" ]; then
      SKIPS+=("$sess: directory gone but it's your current session — skipped")
    else
      P_SESS+=("$sess"); P_PATH+=("$spath"); P_BRANCH+=("-"); P_DEF+=("-"); P_KIND+=("orphan"); P_REASON+=("dir gone"); P_CTX+=("")
    fi
    continue
  fi

  git -C "$spath" rev-parse --is-inside-work-tree >/dev/null 2>&1 || continue   # not a repo (e.g. 'home')
  branch="$(git -C "$spath" symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
  [ -z "$branch" ] && continue                                                  # detached (e.g. review)

  # Fetch+prune once per repo so '[gone]' is accurate.
  cdir="$(cd "$spath" && git rev-parse --git-common-dir 2>/dev/null && :)"
  cdir="$(cd "$spath" && cd "$cdir" 2>/dev/null && pwd || echo "$spath")"
  case " $fetched " in
    *" $cdir "*) ;;
    *) echo "fetching $(basename "$(dirname "$cdir")")..." >&2
       git -C "$spath" fetch -p --quiet 2>/dev/null || true
       fetched="$fetched $cdir" ;;
  esac

  def="$(default_branch "$spath")"
  [ "$branch" = "$def" ] && continue                                            # never prune default branch

  gone=0
  [ "$(git -C "$spath" for-each-ref --format='%(upstream:track)' "refs/heads/$branch" 2>/dev/null)" = "[gone]" ] && gone=1
  merged=0
  if [ "$gone" = 0 ] && command -v gh >/dev/null 2>&1; then
    [ "$(cd "$spath" && gh pr view "$branch" --json state --jq .state 2>/dev/null || true)" = "MERGED" ] && merged=1
  fi
  [ "$gone" = 0 ] && [ "$merged" = 0 ] && continue                              # still active — keep

  reason="merged"; [ "$gone" = 1 ] && reason="upstream gone"

  if [ -n "$(git -C "$spath" status --porcelain 2>/dev/null)" ]; then
    SKIPS+=("$sess ($branch): $reason but has uncommitted changes — skipped")
    continue
  fi
  if [ -n "$CUR" ] && [ "$sess" = "$CUR" ]; then
    SKIPS+=("$sess ($branch): $reason but it's your current session — skipped (run from 'home' or a plain shell)")
    continue
  fi

  if [ -f "$spath/.git" ]; then                                                 # linked worktree (.git is a file)
    kind="worktree"; ctx="$(worktree_for "$spath" "$def")"; [ -z "$ctx" ] && ctx="$spath"
  else                                                                          # regular repo (.git is a dir)
    kind="regular"; ctx=""
  fi
  P_SESS+=("$sess"); P_PATH+=("$spath"); P_BRANCH+=("$branch"); P_DEF+=("$def"); P_KIND+=("$kind"); P_REASON+=("$reason"); P_CTX+=("$ctx")
done < <(tmux -L wsg list-sessions -F '#{session_name}|#{session_path}' 2>/dev/null)

for m in "${SKIPS[@]:-}"; do [ -n "$m" ] && echo "skip: $m"; done

n=${#P_SESS[@]}
[ "$n" = 0 ] && { echo "nothing to prune."; exit 0; }

echo
echo "Will prune $n session(s):"
{
  printf 'SESSION\tBRANCH\tWHY\tKIND\n'
  for i in $(seq 0 $((n - 1))); do
    printf '%s\t%s\t%s\t%s\n' "${P_SESS[$i]}" "${P_BRANCH[$i]}" "${P_REASON[$i]}" "${P_KIND[$i]}"
  done
} | column -t -s "$(printf '\t')"
echo
[ "$HANDOFF" = 1 ] \
  && echo "Each session's Claude context is saved via /handoff before it's killed (--no-handoff to skip)." \
  || echo "(--no-handoff: Claude context will NOT be saved)"
echo

if [ "$YES" != 1 ]; then
  printf "Proceed? [y/N] "
  IFS= read -r ans
  case "$ans" in [yY] | [yY][eE][sS]) ;; *) echo "aborted."; exit 1 ;; esac
fi

# Phase 1 — fire /handoff in every planned session's Claude panes (parallel).
P_PAIRS=()
if [ "$HANDOFF" = 1 ]; then
  echo "saving Claude context (/handoff)... (approving prompts; this can take a bit)"
  for i in $(seq 0 $((n - 1))); do
    [ "${P_KIND[$i]}" = "orphan" ] && { P_PAIRS[$i]=""; continue; }   # dead dir — nothing to save
    P_PAIRS[$i]="$(~/.scripts/handoff-session.sh fire "${P_SESS[$i]}" 2>/dev/null | tr '\n' ' ')"
  done
  # Phase 2 — approve prompts + wait once for all handoff files to settle.
  # shellcheck disable=SC2086
  ~/.scripts/handoff-session.sh await 180 ${P_PAIRS[*]:-} >/dev/null 2>&1 || true
fi

# Phase 3 — act on each session (skip any whose handoff didn't finish).
for i in $(seq 0 $((n - 1))); do
  sess="${P_SESS[$i]}"; spath="${P_PATH[$i]}"; branch="${P_BRANCH[$i]}"
  def="${P_DEF[$i]}"; kind="${P_KIND[$i]}"; reason="${P_REASON[$i]}"; ctx="${P_CTX[$i]}"
  pairs="${P_PAIRS[$i]:-}"
  if [ "$HANDOFF" = 1 ] && [ -n "${pairs// /}" ]; then
    # shellcheck disable=SC2086
    if ! ~/.scripts/handoff-session.sh check $pairs; then
      echo "skip: $sess — Claude /handoff didn't finish in time; left intact" >&2
      continue
    fi
  fi
  if [ "$kind" = "orphan" ]; then
    echo "killing orphan session '$sess' (directory already gone)..."
  elif [ "$kind" = "worktree" ]; then
    echo "removing worktree '$branch' + session '$sess'..."
    wt -C "$ctx" remove "$branch" -f -y >/dev/null 2>&1 || echo "  warn: 'wt remove $branch' failed" >&2
  else
    echo "regular repo '$sess': switching to '$def', deleting '$branch'..."
    git -C "$spath" switch "$def" >/dev/null 2>&1 || echo "  warn: couldn't switch '$sess' to '$def' — leaving as-is" >&2
    if ! git -C "$spath" branch -d "$branch" >/dev/null 2>&1; then
      if [ "$reason" = merged ]; then
        git -C "$spath" branch -D "$branch" >/dev/null 2>&1 || echo "  warn: couldn't delete '$branch'" >&2
      else
        echo "  warn: '$branch' not fully merged locally — branch kept (upstream gone)" >&2
      fi
    fi
  fi
  tmux -L wsg kill-session -t "$sess" 2>/dev/null || true
done
echo "done."
