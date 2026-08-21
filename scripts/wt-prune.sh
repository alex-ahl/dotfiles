#!/usr/bin/env bash
# wt-prune [-y] [--no-handoff | --handoff-ask]
#
# Sweep all wsg tmux sessions and clean up finished ones. Prints a plan and
# asks for confirmation (unless -y) before changing anything.
#
# A session qualifies when its branch is either:
#   • merged — has a MERGED PR (via `gh pr view`), or
#   • gone   — upstream deleted on the remote (git '[gone]').
#
#   linked worktree → worktree removed AND session killed.
#   regular repo    → switched back to default, merged branch deleted, session killed.
#
# Always skipped: the default branch, dirty worktrees, and the current session.

set -Eeuo pipefail

YES=0
HANDOFF_MODE=all          # all | ask | none
for arg in "$@"; do
  case "$arg" in
    -y | --yes) YES=1 ;;
    --no-handoff) HANDOFF_MODE=none ;;
    --handoff-ask) HANDOFF_MODE=ask ;;
    *) echo "usage: wt-prune [-y] [--no-handoff | --handoff-ask]" >&2; exit 1 ;;
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

  # Orphan: session's directory gone (worktree removed under it) — kill the dead session.
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
    *) case "$cdir" in
         */.bare | */.git) repo="$(basename "$(dirname "$cdir")")" ;;          # bare-worktree / regular repo
         *) repo="$(basename "$(git -C "$spath" rev-parse --show-toplevel 2>/dev/null)")" ;;  # submodule/other
       esac
       echo "fetching ${repo:-$sess}..." >&2
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
[ "$HANDOFF_MODE" != none ] \
  && echo "Each session's agent context is saved via /handoff before it's killed (--no-handoff to skip)." \
  || echo "(--no-handoff: agent context will NOT be saved)"
echo

if [ "$YES" != 1 ]; then
  printf "Proceed? [y/N] "
  IFS= read -r ans
  case "$ans" in [yY] | [yY][eE][sS]) ;; *) echo "aborted."; exit 1 ;; esac
fi

# Phase 1 — fire /handoff in every planned session's agent panes (parallel).
P_PAIRS=()
if [ "$HANDOFF_MODE" != "none" ]; then
  echo "saving agent context (/handoff). Note: a session whose agent prompts for"
  echo "permission (e.g. started before the handoff settings) can't be saved"
  echo "unattended and will be skipped after a short wait."
  fired=0
  for i in $(seq 0 $((n - 1))); do
    [ "${P_KIND[$i]}" = "orphan" ] && { P_PAIRS[$i]=""; continue; }   # dead dir — nothing to save
    if [ "$HANDOFF_MODE" = "ask" ]; then
      printf "  save context for '%s' (%s)? [y/N] " "${P_SESS[$i]}" "${P_BRANCH[$i]}"
      IFS= read -r ha
      case "$ha" in [yY]*) ;; *) P_PAIRS[$i]=""; continue ;; esac
    fi
    P_PAIRS[$i]="$(~/.scripts/handoff-session.sh fire "${P_SESS[$i]}" 2>/dev/null | tr '\n' ' ')"
    fired=1
  done
  # Phase 2 — wait (bounded) for the fired handoff files to settle. Sessions that
  # prompt (old/no-permission) never settle and get skipped in phase 3.
  if [ "$fired" = 1 ]; then
    echo "waiting up to 45s for handoffs to finish..."
    # shellcheck disable=SC2086
    ~/.scripts/handoff-session.sh await 45 ${P_PAIRS[*]:-} >/dev/null 2>&1 || true
  fi
fi

# Phase 3 — act on each session (skip any whose handoff didn't finish).
for i in $(seq 0 $((n - 1))); do
  sess="${P_SESS[$i]}"; spath="${P_PATH[$i]}"; branch="${P_BRANCH[$i]}"
  def="${P_DEF[$i]}"; kind="${P_KIND[$i]}"; reason="${P_REASON[$i]}"; ctx="${P_CTX[$i]}"
  pairs="${P_PAIRS[$i]:-}"
  if [ -n "${pairs// /}" ]; then
    # shellcheck disable=SC2086
    if ! ~/.scripts/handoff-session.sh check $pairs; then
      echo "skip: $sess — agent handoff didn't finish in time; left intact" >&2
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
