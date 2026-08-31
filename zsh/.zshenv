# Homebrew on PATH for ALL zsh invocations, including non-login non-interactive
# `zsh -c` (tmux popups), which source only .zshenv, not .zprofile/.zshrc.
# Guarded so login shells (which run brew shellenv in .zprofile) don't prepend twice.
if [[ ":$PATH:" != *":/opt/homebrew/bin:"* ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# Group-writable by default. The sandvault share is shared between this account
# and sandvault-$USER, which are both in the sandvault group, and its dirs are
# setgid — so 002 keeps every file git writes there editable by whichever
# account touches it next. With 022, a host-side checkout silently strips the
# sandbox's write access to exactly the files git rewrote.
umask 002

function jjq {
    jq -R -r "${1:-.} as \$line | try fromjson catch \$line"
}
. "$HOME/.cargo/env"
