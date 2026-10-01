#!/usr/bin/env bash
# Workspace + tmux session name for a directory. `source` this, then call
# ws_name <dir> / session_name <dir>. Shared by workspace.sh (N, W) and
# wt-session.sh (b, B) so both land on the same session for the same worktree.
#
# Bare-repo worktree: <repo>/<worktree>, or just <repo> at the repo root or
# when the worktree is named after it. Anything else: the dir's basename.

ws_name() {  # $1 = dir
  local dir common bare_root
  # pwd -P on both sides: ~/git is a symlink into the share, git reports the
  # physical path.
  dir="$(cd "$1" && pwd -P)"
  common="$(git -C "$dir" rev-parse --git-common-dir 2>/dev/null || true)"
  if [ -n "$common" ] && \
     [ "$(git -C "$dir" -C "$common" rev-parse --is-bare-repository 2>/dev/null || true)" = "true" ]; then
    bare_root="$(dirname "$(cd "$dir" && cd "$common" && pwd -P)")"
    if [ "$dir" = "$bare_root" ] || [ "$(basename "$dir")" = "$(basename "$bare_root")" ]; then
      basename "$bare_root"
    else
      printf '%s/%s\n' "$(basename "$bare_root")" "$(basename "$dir")"
    fi
  else
    basename "$dir"
  fi
}

# tmux session names can't contain "." (used for window/pane targets).
session_name() {  # $1 = dir
  local ws; ws="$(ws_name "$1")"
  printf '%s\n' "${ws//./_}"
}
