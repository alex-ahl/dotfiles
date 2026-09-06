#!/usr/bin/env bash
# Wire the sandvault share so $USER and sandvault-$USER work the same files.
# Idempotent; re-run after changing agents/install.sh or adding a shared dir.
#
# Shared state lives in /Users/Shared/sv-$USER and is symlinked to ~/<name> on
# BOTH sides, so a ~/-relative path in a skill resolves to the same file inside
# the sandbox and out. The sandbox cannot see /Users/$USER at all.
#
# The repo itself is private to $USER, where the sandbox cannot reach it.
# install.sh deploys the parts the sandbox needs to $SHARE/agent-runtime; this
# script wires the sandbox home to that copy.
#
# Fresh machine: `install.sh` runs this itself once the share exists, so the
# whole setup is
#   git clone <dotfiles> ~/.config/dotfiles && ~/.config/dotfiles/install.sh
# and then the one step that cannot be automated, because it holds live PATs:
#   sv shell, then create $SHARE/user/.zshenv — gh tokens (README, "Not tracked")
# Run this by hand only to re-wire after changing agents/install.sh or DIRS.
set -Eeuo pipefail

SHARE="/Users/Shared/sv-$USER"
SBHOME="/Users/sandvault-$USER"
RUNTIME="$SHARE/agent-runtime"                # deployed by install.sh
DIRS=(git brain handoffs)

command -v sv >/dev/null || { echo "sandvault not installed — brew bundle" >&2; exit 1; }
[ -d "$SHARE" ] || { echo "no $SHARE — run: sv build" >&2; exit 1; }
[ -d "$RUNTIME" ] || { echo "no $RUNTIME — run install.sh from the dotfiles repo first" >&2; exit 1; }

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

# agents/install.sh keys off $HOME, so running it inside links the sandbox's
# config dirs to the deployed runtime. settings.json arrives via stow on the
# host, so it needs linking separately.
# ~/.scripts is how the skills reach shared/repo-resolve.sh et al; the host gets it
# from install.sh pointing at the repo, the sandbox gets the deployed copy.
# Deployed, not live: an edit here reaches the sandbox on the next install.sh.
sv shell -- ln -sfn "$RUNTIME/scripts" "$SBHOME/.scripts"

sv shell -- bash "$RUNTIME/agents/install.sh"
for a in 1 2; do
  sv shell -- ln -sfn "$RUNTIME/agents/claude/.claude-account$a/settings.json" \
                      "$SBHOME/.claude-account$a/settings.json"
done

echo "sandvault: $SHARE shared, sandbox home wired"
