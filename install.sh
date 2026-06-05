#!/usr/bin/env bash
# Symlink all dotfiles into place. Idempotent — safe to re-run.
set -euo pipefail
cd "$(dirname "$0")"

# Install Homebrew packages from the Brewfile (skip with NO_BREW=1). This also
# installs stow itself. Idempotent — already-installed packages are left alone.
if [ -z "${NO_BREW:-}" ] && command -v brew >/dev/null; then
  brew bundle --file="$PWD/Brewfile"
fi

command -v stow >/dev/null || { echo "stow not found — run: brew install stow" >&2; exit 1; }

# Pull in the nvim submodule on a fresh clone.
git submodule update --init --recursive

# Stow packages: each mirrors $HOME. -t "$HOME" because the repo lives under ~/git.
# Existing real dirs (e.g. ~/.claude) are descended into; missing dirs (e.g.
# ~/.config/nvim, ~/.config/tmux) are folded into a single dir symlink.
stow -t "$HOME" \
  zsh git ssh harlequin docker ghostty tmux karabiner worktrunk sol claude nvim

# Scripts are not a stow package — symlink the whole dir to ~/.scripts.
ln -sfn "$PWD/scripts" "$HOME/.scripts"

echo "dotfiles installed. Restart your shell (or: exec zsh)."
