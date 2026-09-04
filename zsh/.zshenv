# Homebrew on PATH for ALL zsh invocations, including non-login non-interactive
# `zsh -c` (tmux popups), which source only .zshenv, not .zprofile/.zshrc.
# Guarded so login shells (which run brew shellenv in .zprofile) don't prepend twice.
if [[ ":$PATH:" != *":/opt/homebrew/bin:"* ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# Pin the git settings that name a command to run, so a repo-local .git/config
# cannot introduce one. GIT_CONFIG_COUNT has -c precedence, which beats local
# config; repos under the sandvault share are writable by sandvault-$USER, and
# a poisoned config would otherwise execute as this account on `git status`,
# `fetch` or `commit`. Only closes keys with fixed names. alias.*, filter.*.clean
# and diff.*.textconv take arbitrary ones, so they can't be pinned; they also
# need a .gitattributes in the working tree, which is tracked and shows up in
# git status.
# Cost: husky's core.hooksPath is overridden too. Opt a repo back in per call:
#   git -c core.hooksPath=.husky/_ commit
export GIT_CONFIG_COUNT=4
export GIT_CONFIG_KEY_0=core.hooksPath   GIT_CONFIG_VALUE_0=/dev/null
export GIT_CONFIG_KEY_1=core.fsmonitor   GIT_CONFIG_VALUE_1=false
export GIT_CONFIG_KEY_2=core.sshCommand  GIT_CONFIG_VALUE_2=ssh
export GIT_CONFIG_KEY_3=core.pager       GIT_CONFIG_VALUE_3=cat

function jjq {
    jq -R -r "${1:-.} as \$line | try fromjson catch \$line"
}
. "$HOME/.cargo/env"
