#!/usr/bin/env bash
# repo-file-suggestion — custom `@` autocomplete source for Claude Code.
# Wired via the `fileSuggestion` setting. Reads {"query":"..."} on stdin and
# prints up to 15 newline-separated paths on stdout.
#
# It REPLACES the built-in file finder, so it returns both:
#   1. repo matches  — query against repo names under ~/git, resolved to their
#      readable path (regular dir or default-branch worktree), listed first.
#   2. project files — fd over CLAUDE_PROJECT_DIR (literal, full-path match),
#      preserving normal @-file completion.
set -Eeuo pipefail

LIMIT=15
RESOLVE="$HOME/.scripts/repo-resolve.sh"
PROJ="${CLAUDE_PROJECT_DIR:-$PWD}"

# Query from stdin JSON (jq if present, else python3 fallback).
input="$(cat)"
if command -v jq >/dev/null 2>&1; then
  query="$(printf '%s' "$input" | jq -r '.query // ""' 2>/dev/null || true)"
else
  query="$(printf '%s' "$input" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("query",""))' 2>/dev/null || true)"
fi

lc() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

emit=()  # collected suggestions, in priority order

# 1. Repo matches (only when there's a query — empty query shouldn't dump every repo).
#    "repo/partial" browses that repo's worktrees; a plain name matches repos.
if [ -n "$query" ] && [ -x "$RESOLVE" ]; then
  case "$query" in
    */*)
      repo_part="${query%%/*}"; wt_part="${query#*/}"; wtl="$(lc "$wt_part")"
      while IFS= read -r wt; do
        [ -n "$wt" ] || continue
        if [ -z "$wt_part" ]; then
          emit+=("$wt")
        else
          case "$(lc "$(basename "$wt")")" in *"$wtl"*) emit+=("$wt") ;; esac
        fi
      done < <("$RESOLVE" --worktrees "$repo_part" 2>/dev/null)
      ;;
    *)
      ql="$(lc "$query")"
      while IFS= read -r root; do
        [ -n "$root" ] || continue
        case "$(lc "$(basename "$root")")" in
          *"$ql"*) emit+=("$("$RESOLVE" --path "$root" 2>/dev/null || true)") ;;
        esac
      done < <("$RESOLVE" --list 2>/dev/null)
      ;;
  esac
fi

# 2. Project files via fd (literal substring against the full path).
if command -v fd >/dev/null 2>&1; then
  if [ -n "$query" ]; then
    while IFS= read -r f; do emit+=("$f"); done < <(
      fd --type f --hidden --exclude .git --fixed-strings --full-path "$query" "$PROJ" 2>/dev/null
    )
  else
    while IFS= read -r f; do emit+=("$f"); done < <(
      fd --type f --hidden --exclude .git "" "$PROJ" 2>/dev/null
    )
  fi
fi

# Dedupe (keep first occurrence / priority order) and cap at LIMIT.
[ "${#emit[@]}" -gt 0 ] && printf '%s\n' "${emit[@]}" \
  | awk 'NF && !seen[$0]++' \
  | head -n "$LIMIT"
