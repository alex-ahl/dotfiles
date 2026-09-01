#!/usr/bin/env bash
# Symlink all dotfiles into place. Idempotent — safe to re-run.
set -euo pipefail
cd "$(dirname "$0")"

# Install Homebrew packages from the Brewfile (skip with NO_BREW=1); this also
# installs stow itself. Idempotent.
if [ -z "${NO_BREW:-}" ] && command -v brew >/dev/null; then
  brew bundle --file="$PWD/Brewfile"
fi

command -v stow >/dev/null || { echo "stow not found — run: brew install stow" >&2; exit 1; }

# Pull in the nvim submodule on a fresh clone.
git submodule update --init --recursive

# Stow packages: each mirrors $HOME. -t "$HOME" since the repo lives under ~/git.
# Existing real dirs (e.g. ~/.claude) are descended into; missing dirs (e.g.
# ~/.config/nvim) are folded into a single dir symlink.
stow -t "$HOME" \
  zsh git ssh harlequin docker ghostty tmux karabiner worktrunk sol nvim

# ssh refuses a group- or world-writable config, and umask 002 (see zsh/.zshenv)
# makes a checkout produce 664. Pin it — 640 still lets the sandbox read it.
chmod 640 "$PWD/ssh/.ssh/config"

# The egress allowlist is the user's to extend, so the sandbox account reads it
# but must not write it — otherwise an agent can approve its own domains.
chmod 644 "$PWD/scripts/lib/srt-settings.json"

# Agent configs live under agents/ so multiple agents (claude, opencode, ...)
# can be sibling packages. Stow with agents/ as the stow dir, so e.g.
# agents/claude/.claude-account1/ maps to ~/.claude-account1/.
stow -d "$PWD/agents" -t "$HOME" claude

# Scripts are not a stow package — symlink the whole dir to ~/.scripts.
ln -sfn "$PWD/scripts" "$HOME/.scripts"

# Link shared agent commands + skills into each agent's config dirs.
# Not stow — targets live inside runtime dirs.
"$PWD/agents/install.sh"

echo "dotfiles installed. Restart your shell (or: exec zsh)."
