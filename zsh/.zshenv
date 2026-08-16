# Homebrew on PATH for ALL zsh invocations — including non-login,
# non-interactive `zsh -c` used by tmux popups, which source only .zshenv
# (not .zprofile/.zshrc). Guarded so login shells (which also run brew
# shellenv in .zprofile) don't prepend it twice.
if [[ ":$PATH:" != *":/opt/homebrew/bin:"* ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

function jjq {
    jq -R -r "${1:-.} as \$line | try fromjson catch \$line"
}
. "$HOME/.cargo/env"
