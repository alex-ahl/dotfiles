#!/usr/bin/env bash
# repo-resolve — resolve a short repo name (and optional worktree) to a readable
# absolute path.
#
# Scans ~/git for git repo roots and handles both layouts:
#   • regular clone (.git is a dir)        -> the repo dir itself
#   • bare-with-worktrees (.bare / bare    -> the default-branch worktree inside
#     .git file, no source at the root)       (e.g. .../k8s-apps/master)
#
# Usage:
#   repo-resolve <query> [worktree]   resolve a repo; with a 2nd arg, pick that
#                                     worktree (matched by dir name OR branch).
#   repo-resolve --list               print every repo ROOT dir (cheap)
#   repo-resolve --path <dir>         print the readable path for a repo root
#   repo-resolve --worktrees <query>  print the worktree paths of a repo
# Exit: 0 ok, 2 usage, 3 ambiguous (candidates on stderr), 4 none.
set -Eeuo pipefail

GIT_ROOT="${GIT_ROOT:-$HOME/git}"
MAXDEPTH="${REPO_RESOLVE_MAXDEPTH:-3}"

lc() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

# Find repo roots, stopping descent once one is found. Fills global `roots`.
scan_roots() {
  roots=()
  _scan() {  # $1 = dir, $2 = depth
    local d="$1" depth="$2" sub base
    if [ -e "$d/.git" ] || [ -d "$d/.bare" ]; then roots+=("$d"); return; fi
    [ "$depth" -ge "$MAXDEPTH" ] && return
    for sub in "$d"/*/; do
      [ -d "$sub" ] || continue
      base="$(basename "$sub")"
      case "$base" in .* | node_modules) continue ;; esac
      _scan "${sub%/}" "$((depth + 1))"
    done
  }
  _scan "$GIT_ROOT" 0
}

# Resolve a unique repo root for a query. Prints the root on stdout, or exits
# 3 (ambiguous, candidates on stderr) / 4 (none).
resolve_repo_root() {  # $1 = query
  local q r n
  scan_roots
  [ "${#roots[@]}" -eq 0 ] && { echo "no git repos found under $GIT_ROOT" >&2; exit 4; }
  q="$(lc "$1")"
  local exact=() subm=()
  for r in "${roots[@]}"; do
    n="$(lc "$(basename "$r")")"
    if [ "$n" = "$q" ]; then exact+=("$r")
    elif case "$n" in *"$q"*) true ;; *) false ;; esac; then subm+=("$r"); fi
  done
  local matches=()
  if [ "${#exact[@]}" -gt 0 ]; then matches=("${exact[@]}")
  elif [ "${#subm[@]}" -gt 0 ]; then matches=("${subm[@]}")
  else echo "no repo under $GIT_ROOT matches '$1'" >&2; exit 4; fi
  if [ "${#matches[@]}" -gt 1 ]; then
    echo "multiple repos match '$1' — be more specific:" >&2
    printf '  %s\n' "${matches[@]}" >&2
    exit 3
  fi
  printf '%s\n' "${matches[0]}"
}

# Echo the default readable path for a repo root.
resolve_root() {  # $1 = repo root
  local root="$1" def wt
  if [ -d "$root/.bare" ] || [ "$(git -C "$root" rev-parse --is-bare-repository 2>/dev/null)" = "true" ]; then
    def="$(git -C "$root" symbolic-ref --short HEAD 2>/dev/null || true)"
    if [ -n "$def" ] && [ -d "$root/$def" ]; then printf '%s\n' "$root/$def"; return 0; fi
    wt="$(list_worktrees "$root" | head -1 | cut -f1)"
    if [ -n "$wt" ] && [ "$wt" != "$root" ]; then printf '%s\n' "$wt"; return 0; fi
    printf '%s\n' "$root"; return 0
  fi
  printf '%s\n' "$root"
}

# Print "path<TAB>branch" for each non-bare worktree of a repo root.
list_worktrees() {  # $1 = repo root
  git -C "$1" worktree list --porcelain 2>/dev/null | awk '
    function flush(){ if(p!="" && !bare) print p "\t" br; p="";br="";bare=0 }
    /^worktree /{ flush(); p=substr($0,10) }
    /^bare$/{ bare=1 }
    /^branch /{ br=substr($0,8); sub(/^refs\/heads\//,"",br) }
    /^detached$/{ br="(detached)" }
    END{ flush() }'
}

# Pick worktree path(s) whose dir name OR branch matches a query (exact first).
pick_worktree() {  # $1 = query ; stdin = "path<TAB>branch" lines
  awk -F'\t' -v q="$(lc "$1")" '
    { p=$1; b=$2; bp=tolower(p); sub(/.*\//,"",bp); lb=tolower(b);
      if(bp==q||lb==q) ex[ne++]=p;
      else if(index(bp,q)||index(lb,q)) su[ns++]=p; }
    END{ if(ne){for(i=0;i<ne;i++)print ex[i]} else if(ns){for(i=0;i<ns;i++)print su[i]} }'
}

# --- Modes -------------------------------------------------------------------
case "${1:-}" in
  --list)
    scan_roots
    [ "${#roots[@]}" -gt 0 ] && printf '%s\n' "${roots[@]}"
    exit 0
    ;;
  --path)
    [ -n "${2:-}" ] || { echo "usage: repo-resolve --path <dir>" >&2; exit 2; }
    resolve_root "$2"
    exit 0
    ;;
  --worktrees)
    [ -n "${2:-}" ] || { echo "usage: repo-resolve --worktrees <query>" >&2; exit 2; }
    root="$(resolve_repo_root "$2")"
    list_worktrees "$root" | cut -f1
    exit 0
    ;;
  "")
    echo "usage: repo-resolve <query> [worktree] | --list | --path <dir> | --worktrees <query>" >&2
    exit 2
    ;;
esac

QUERY="$1"; WT="${2:-}"
root="$(resolve_repo_root "$QUERY")"

if [ -z "$WT" ]; then
  resolve_root "$root"
  exit 0
fi

# Worktree requested — match it within the repo.
hits="$(list_worktrees "$root" | pick_worktree "$WT")"
n="$(printf '%s' "$hits" | grep -c . || true)"
if [ "$n" -eq 0 ]; then
  echo "no worktree of '$QUERY' matches '$WT'. Available:" >&2
  list_worktrees "$root" | awk -F'\t' '{printf "  %s  [%s]\n",$1,$2}' >&2
  exit 4
elif [ "$n" -gt 1 ]; then
  echo "multiple worktrees of '$QUERY' match '$WT' — be more specific:" >&2
  printf '%s\n' "$hits" | sed 's/^/  /' >&2
  exit 3
fi
printf '%s\n' "$hits"
