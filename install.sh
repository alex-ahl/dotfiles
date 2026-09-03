#!/usr/bin/env bash
# Symlink all dotfiles into place. Idempotent — safe to re-run.
set -euo pipefail
cd "$(dirname "$0")"

# Install Homebrew packages from the Brewfile (skip with NO_BREW=1); this also
# installs stow itself. Idempotent.
#
# --no-upgrade: install what is missing, leave installed versions where they are.
# A formula has one version stream, so an upgrade here can be a major bump nobody
# asked for as a side effect of stowing dotfiles — node especially, which srt is
# installed under globally. Upgrade deliberately: `brew bundle --file=...`.
#
# Non-fatal: set -e made a single cask that fails to upgrade veto everything
# below it — the stow and the sandbox deploy, which are the part that matters.
if [ -z "${NO_BREW:-}" ] && command -v brew >/dev/null; then
  brew bundle --no-upgrade --file="$PWD/Brewfile" \
    || echo "brew bundle failed — continuing with stow + deploy" >&2
fi

command -v stow >/dev/null || { echo "stow not found — run: brew install stow" >&2; exit 1; }

# Pull in the nvim submodule on a fresh clone.
git submodule update --init --recursive

# Stow packages: each mirrors $HOME. -t "$HOME" since the repo lives under ~/git.
# Existing real dirs (e.g. ~/.claude) are descended into; missing dirs (e.g.
# ~/.config/nvim) are folded into a single dir symlink.
stow -t "$HOME" \
  zsh git ssh harlequin docker ghostty tmux karabiner worktrunk nvim

# Sol separately. It rewrites config.json by atomic replace, so the stow symlink
# becomes a real file within seconds of launch — which is why a plain stow here
# aborts on a conflict. mkdir first: without an existing dir stow folds the whole
# of ~/.config/sol, and Sol keeps real state there (mmkv, state.json) that has no
# business in the repo. --adopt takes the app's file back and restores the link.
# skip-worktree then keeps Sol's history/frequencies churn out of git status —
# the committed copy is a settings seed for a fresh machine, not a live mirror.
# To capture a setting change deliberately:
#   git update-index --no-skip-worktree sol/.config/sol/config.json
#   git add -p && git update-index --skip-worktree sol/.config/sol/config.json
mkdir -p "$HOME/.config/sol"
stow --adopt -t "$HOME" sol
git update-index --skip-worktree sol/.config/sol/config.json

# ssh refuses a group- or world-writable config, and umask 002 (see zsh/.zshenv)
# makes a checkout produce 664. Pin it — 640 still lets the sandbox read it.
chmod 640 "$PWD/ssh/.ssh/config"

# Agent configs live under agents/ so multiple agents (claude, opencode, ...)
# can be sibling packages. Stow with agents/ as the stow dir, so e.g.
# agents/claude/.claude-account1/ maps to ~/.claude-account1/.
stow -d "$PWD/agents" -t "$HOME" claude

# Scripts are not a stow package — symlink the whole dir to ~/.scripts.
ln -sfn "$PWD/scripts" "$HOME/.scripts"

# Link shared agent commands + skills into each agent's config dirs.
# Not stow — targets live inside runtime dirs.
"$PWD/agents/install.sh"

# This repo is private to $USER; the sandbox account cannot read /Users/$USER.
# What it needs is deployed outward as copies — copies, not symlinks, so an
# agent write in the share never reaches anything the host runs. Re-run
# install.sh to publish an edit.
SHARE="/Users/Shared/sv-$USER"
if [ -d "$SHARE" ]; then
  # srt reads the allowlist as sandvault-$USER, so it cannot live in this repo.
  # Kept outside $SHARE, where `sv -r`'s ACL walk never reaches it; /Users/Shared
  # is sticky, so only this account can replace the dir.
  POLICY="/Users/Shared/$USER-policy"
  mkdir -p "$POLICY"
  chmod 755 "$POLICY"
  install -m 644 "$PWD/scripts/lib/srt-settings.json" "$POLICY/srt-settings.json"

  # The sandbox's ~/.scripts, skills, commands and agent settings.
  # sandvault-sync.sh wires the sandbox home to this copy.
  # Rebuilt from scratch each run: --delete only prunes inside a synced subtree,
  # so anything deployed by an older layout would linger here forever.
  RUNTIME="$SHARE/agent-runtime"
  rm -rf "$RUNTIME"
  mkdir -p "$RUNTIME/scripts"
  rsync -a --exclude .git "$PWD/scripts/shared/" "$RUNTIME/scripts/shared/"
  rsync -a --exclude .git "$PWD/agents/"         "$RUNTIME/agents/"
fi

echo "dotfiles installed. Restart your shell (or: exec zsh)."
