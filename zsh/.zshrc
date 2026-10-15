# An interactive ssh login lands in the tmux home session, as a Ghostty window
# does on the Mac. Non-interactive ssh (scp, rsync, `ssh host cmd`) is
# untouched. Detaching ends the connection; if tmux fails to start, the plain
# shell stays instead.
if [[ -n $SSH_CONNECTION && -z $TMUX && -o interactive ]] && (( $+commands[tmux] )); then
  # Ghostty sends TERM=xterm-ghostty, which a remote box rarely has terminfo
  # for, and tmux won't start without it.
  infocmp $TERM &>/dev/null || export TERM=xterm-256color
  ~/.scripts/start-tmux.sh && exit
fi

# tmux chdirs a pane to the resolved path, so a shell opened in the sandvault
# share starts at /Users/Shared/sv-$USER/... and the prompt shows all of it.
# Re-enter the same directory through the ~/git, ~/brain, ~/handoffs symlinks
# (scripts/sandvault-sync.sh) so it reads ~/git/... — the same ~-relative path
# on both sides of the sandbox, and what tmux's status line already prints.
# Must run before the instant prompt below, which renders the first cwd.
() {
  [[ -L $HOME/git ]] || return              # not a sandvault machine
  local share=${${:-$HOME/git}:A:h} logical # /Users/Shared/sv-$USER
  [[ $PWD == $share/* ]] || return
  logical=$HOME${PWD#$share}
  [[ $logical -ef $PWD ]] && cd -q -- $logical
}

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="powerlevel10k/powerlevel10k"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
# zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line to change how often to auto-update (in days).
# zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(git docker gcloud kubectl helm) 

source $ZSH/oh-my-zsh.sh

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='mvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"
alias pfw=~/git/utils/env-port-forward.sh
alias ns="pnpm start | jjq"
[[ $OSTYPE == darwin* ]] && alias jsontidy="pbpaste | jq '.' | pbcopy"
alias claude1='CLAUDE_CONFIG_DIR=~/.claude-account1 claude'
alias claude2='CLAUDE_CONFIG_DIR=~/.claude-account2 claude'
alias wsg=~/.scripts/workspace.sh
alias wsg-ls='tmux -L wsg ls -F "#S"'
alias wsg-pick='tmux -L wsg attach -t "$(tmux -L wsg ls -F "#S" | fzf)"'
alias cb=~/.scripts/clone-bare.sh
alias cwt=~/.scripts/check-worktrees.sh
alias wtp=~/.scripts/wt-prune.sh

# F12 in tmux passes every key to a nested tmux over ssh. Once that ssh ends,
# take the keys back for this pane's session; otherwise they keep going to
# this plain shell and no tmux binding works.
_tmux_ssh_preexec() { [[ $1 == ssh || $1 == "ssh "* ]] && _tmux_after_ssh=1 }
_tmux_ssh_precmd() {
  (( ${_tmux_after_ssh:-0} )) || return
  _tmux_after_ssh=0
  [[ -n $TMUX ]] && tmux set -t "$TMUX_PANE" -u prefix \; set -t "$TMUX_PANE" -u key-table \; refresh-client -S
}
preexec_functions+=(_tmux_ssh_preexec)
precmd_functions+=(_tmux_ssh_precmd)

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

test -e "${HOME}/.iterm2_shell_integration.zsh" && source "${HOME}/.iterm2_shell_integration.zsh"


export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

[ -f "$HOME/.ghcup/env" ] && . "$HOME/.ghcup/env" # ghcup-env
# The following lines have been added by Docker Desktop to enable Docker CLI completions.
fpath=($HOME/.docker/completions $fpath)
autoload -Uz compinit
compinit
# End of Docker CLI completions
export PATH="$HOME/.local/bin:$PATH"

# /etc/paths.d/dotnet-cli-tools writes a literal `~/.dotnet/tools` that
# path_helper does NOT expand, so global dotnet tools (e.g. dotnet-easydotnet
# for easy-dotnet.nvim) aren't on PATH. Add the resolved path here.
export PATH="$HOME/.dotnet/tools:$PATH"

iterm2_print_user_vars() {
  iterm2_set_user_var project "$(basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)")"
}

tn() {
  osascript -e "tell application \"iTerm2\" to tell current session of current window to set name to \"$1\""
}

if command -v wt >/dev/null 2>&1; then eval "$(command wt config shell init zsh)"; fi
