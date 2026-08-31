#!/usr/bin/env bash
# Route `gh` to the right token. A fine-grained PAT is pinned to one resource
# owner, so covering both a personal account and an employer org needs one token
# each — and gh only accepts one per call.
#
# Sourced from the sandbox's $SHARED_WORKSPACE/user/.zshenv, which holds the two
# tokens and $GH_OWNER_PERSONAL, and nothing else. Account and org names live
# there rather than here: the employer can change, this logic doesn't. That file
# is read by ZSH, so keep this body valid under bash and zsh both — no arrays, no
# bash-only syntax.
#
# Inert unless a token is set, so it never hijacks a shell that already has full
# `gh` auth of its own (the host account does).

[ -n "${GH_TOKEN_WORK:-}${GH_TOKEN_PERSONAL:-}" ] || return 0

_gh_with() {  # $1 = token ("" → inherit ambient auth); rest = gh args
  local tok="$1"; shift
  if [ -n "$tok" ]; then GH_TOKEN="$tok" command gh "$@"
  else                   command gh "$@"; fi
}

# Owner implied by the args, if any. The target repo hides in four shapes:
# `--repo o/r`, a bare positional `o/r` (gh repo view), a `/repos/o/r/...` path
# (gh api), or a github.com URL. Missing one silently routes by cwd instead,
# which reads as a 404 rather than an error.
_gh_owner() {
  local a prev=''
  for a in "$@"; do
    if [ "$prev" = --repo ]; then printf '%s' "${a%%/*}"; return; fi
    prev="$a"
    case "$a" in
      /repos/*/*|repos/*/*)   a="${a#/}"; a="${a#repos/}"; printf '%s' "${a%%/*}"; return ;;
      https://github.com/*/*) a="${a#https://github.com/}"; printf '%s' "${a%%/*}"; return ;;
      -*|/*|*/*/*)            ;;   # flag, absolute path, or too deep to be o/r
      */*)                    printf '%s' "${a%%/*}"; return ;;
    esac
  done
}

gh() {
  local a owner='' t json=0
  for a in "$@"; do [ "$a" = --json ] && json=1; done
  owner="$(_gh_owner "$@")"

  # `search` uses the search API, which spans owners — and neither token can see
  # the other's repos, so run both and union. No dedup needed: one owner per repo.
  if [ "${1:-}" = search ]; then
    if [ "$json" = 1 ]; then
      # Two invocations emit two JSON arrays; slurp and merge into one.
      { for t in "$GH_TOKEN_WORK" "$GH_TOKEN_PERSONAL"; do
          [ -n "$t" ] || continue
          _gh_with "$t" "$@"
        done
      } | jq -s '(add // []) | sort_by(.updatedAt // "") | reverse'
    else
      for t in "$GH_TOKEN_WORK" "$GH_TOKEN_PERSONAL"; do
        [ -n "$t" ] || continue
        _gh_with "$t" "$@"
      done
    fi
    return
  fi

  # Everything else is repo-scoped (`gh pr list` and `gh issue list` fail outside
  # a repo), so pick by the target's owner. A wrong pick reads as "Could not
  # resolve to a Repository" — a 404, not a 403.
  [ -n "$owner" ] || owner="$(command git remote get-url origin 2>/dev/null \
                              | sed -E 's#.*[:/]([^/]+)/[^/]+$#\1#')"

  # Only the personal owner is named; everything else — every org, present or
  # future — is work. An unresolved owner falls here too, which is the safer
  # default: it's where the great majority of repos live.
  if [ -n "${GH_OWNER_PERSONAL:-}" ] && [ "$owner" = "${GH_OWNER_PERSONAL}" ]; then
    _gh_with "${GH_TOKEN_PERSONAL:-}" "$@"
  else
    _gh_with "${GH_TOKEN_WORK:-}" "$@"
  fi
}
