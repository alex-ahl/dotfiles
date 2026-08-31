#!/usr/bin/env bash
# Wire the sandvault share so $USER and sandvault-$USER work the same files.
# Idempotent; re-run after changing agents/install.sh or adding a shared dir.
#
# Shared state lives in /Users/Shared/sv-$USER and is symlinked to ~/<name> on
# BOTH sides, so a ~/-relative path in a skill resolves to the same file inside
# the sandbox and out. The sandbox cannot see /Users/$USER at all.
#
# Fresh machine, in order — the repo must sit inside the share, which only
# exists after `sv build`:
#   brew bundle
#   sv build
#   git clone <dotfiles> /Users/Shared/sv-$USER/git/dotfiles
#   scripts/sandvault-sync.sh
#   sv shell, then create $SHARE/user/.zshenv — gh tokens (README, "Not tracked")
set -Eeuo pipefail

SHARE="/Users/Shared/sv-$USER"
SBHOME="/Users/sandvault-$USER"
REPO="$(cd "$(dirname "$0")/.." && pwd -P)"   # -P: reached via the ~/git symlink
DIRS=(git brain handoffs)

command -v sv >/dev/null || { echo "sandvault not installed — brew bundle" >&2; exit 1; }
[ -d "$SHARE" ] || { echo "no $SHARE — run: sv build" >&2; exit 1; }
case "$REPO" in "$SHARE"/*) ;; *) echo "repo is outside $SHARE — the sandbox can't read it" >&2; exit 1 ;; esac

# A real dir at ~/<name> is refused, not replaced: `ln -sfn` nests inside it.
for d in "${DIRS[@]}"; do
  [ -d "$HOME/$d" ] && [ ! -L "$HOME/$d" ] && { echo "$HOME/$d is a real directory — move it into $SHARE first" >&2; exit 1; }
  mkdir -p "$SHARE/$d"
  ln -sfn "$SHARE/$d" "$HOME/$d"
done

# Same names inside, where $HOME is $SBHOME. Linked directly, not staged in
# $SHARE/user: ~/configure rsyncs that with --copy-links, so links would arrive
# as copies and drift.
for d in "${DIRS[@]}"; do
  sv shell -- rm -rf "$SBHOME/$d"
  sv shell -- ln -sfn "$SHARE/$d" "$SBHOME/$d"
done

# install.sh keys off $HOME, so running it inside links the sandbox's config
# dirs to the shared repo — skill edits stay live. settings.json arrives via
# stow on the host, so it needs linking separately.
# ~/.scripts is how the skills reach repo-resolve.sh et al; the host gets it
# from install.sh, the sandbox needs its own.
sv shell -- ln -sfn "$REPO/scripts" "$SBHOME/.scripts"

sv shell -- bash "$REPO/agents/install.sh"
for a in 1 2; do
  sv shell -- ln -sfn "$REPO/agents/claude/.claude-account$a/settings.json" \
                      "$SBHOME/.claude-account$a/settings.json"
done

echo "sandvault: $SHARE shared, sandbox home wired"
