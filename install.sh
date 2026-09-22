#!/usr/bin/env bash
# Symlink all dotfiles into place. Idempotent — safe to re-run.
set -euo pipefail
cd "$(dirname "$0")"

# Output helpers. Colour only on a terminal, and honour NO_COLOR / TERM=dumb —
# same guard as clone-bare.sh, so a piped or logged run stays plain text.
if [ -t 1 ] && [ -z "${NO_COLOR-}" ] && [ "${TERM-}" != dumb ]; then
  BLUE='\033[0;34m' GREEN='\033[0;32m' YELLOW='\033[1;33m' NOFORMAT='\033[0m'
else
  BLUE='' GREEN='' YELLOW='' NOFORMAT=''
fi
step() { printf "${BLUE}==>${NOFORMAT} %s\n" "$1"; }
ok()   { printf "${GREEN}==>${NOFORMAT} %s\n" "$1"; }
warn() { printf "${YELLOW}  ! %s${NOFORMAT}\n" "$1" >&2; }

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
  step "Homebrew packages"
  # The Brewfile taps two third-party taps, and brew refuses to even check a
  # formula from an untrusted one — which failed the whole bundle. Granted per
  # formula rather than per tap on purpose: a formula added to either tap later
  # does not inherit the grant. Committing the list here is the approval record.
  # Idempotent; a second run just reports "Already trusted".
  for f in hashicorp/tap/terraform oven-sh/bun/bun; do
    brew trust --formula "$f" >/dev/null 2>&1 || true
  done
  brew bundle --no-upgrade --file="$PWD/Brewfile" \
    || warn "brew bundle failed — continuing with stow + deploy"
  # Packages from private repos are not in the public Brewfile; see README,
  # "Not tracked". Absent on a machine that does not need them.
  if [ -f "$PWD/Brewfile.local" ]; then
    brew bundle --no-upgrade --file="$PWD/Brewfile.local" \
      || warn "local brew bundle failed — continuing with stow + deploy"
  fi
fi

command -v stow >/dev/null || { warn "stow not found — run: brew install stow"; exit 1; }

step "Dotfiles"

# Pull in the nvim submodule on a fresh clone.
git submodule update --init --recursive

# Stow packages: each mirrors $HOME. -t "$HOME"; the repo itself lives under
# ~/.config, outside the share (see README, "Where this repo lives").
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

# Agent configs live under agents/ so multiple agents (claude, opencode, ...)
# can be sibling packages. Stow with agents/ as the stow dir, so e.g.
# agents/claude/.claude-account1/ maps to ~/.claude-account1/.
# Pre-create the targets: stow folds a *missing* directory into one symlink, so
# on a fresh machine ~/.claude-account1 would become a link into this repo and
# Claude would write its sessions, history and credentials inside it.
mkdir -p "$HOME/.claude" "$HOME/.claude-account1" "$HOME/.claude-account2"
stow -d "$PWD/agents" -t "$HOME" claude

# Scripts are not a stow package — symlink the whole dir to ~/.scripts.
# Refuse a real dir rather than nesting the link inside it, same as the share
# links below: `ln -sfn` into an existing directory creates ~/.scripts/scripts.
if [ -d "$HOME/.scripts" ] && [ ! -L "$HOME/.scripts" ]; then
  warn "$HOME/.scripts is a real directory — move it aside, then re-run"
else
  ln -sfn "$PWD/scripts" "$HOME/.scripts"
fi

step "Agent configs"

# Link shared agent commands + skills into each agent's config dirs.
# Not stow — targets live inside runtime dirs.
"$PWD/agents/install.sh"

# --- sandbox ----------------------------------------------------------------
# One command for a new machine, and the same command afterwards: every step is
# guarded, so a re-run costs a couple of stats and changes nothing. Order is
# load-bearing — the share has to exist before the runtime is deployed into it,
# and the runtime before the sandbox home is wired to that copy.
step "Sandbox"

SHARE="/Users/Shared/sv-$USER"
SBHOME="/Users/sandvault-$USER"

# `sv build` creates the sandvault account and the share; it needs sudo, so say
# what is about to happen. Guarded on the share, not run every time.
if [ ! -d "$SHARE" ] && command -v sv >/dev/null; then
  warn "no $SHARE yet — running sv build (sudo; creates the sandvault-$USER account)"
  sv build
fi

# ~/git, ~/brain and ~/handoffs live in the share and are symlinked from $HOME on
# both sides. sandvault-sync.sh does the sandbox side (it needs `sv shell`); the
# host side is three symlinks. Without ~/git the workspace picker lists no repos
# and cannot say why — fzf repaints over anything written to stderr.
if [ -d "$SHARE" ]; then
  for d in git brain handoffs; do
    # A real dir here is someone's data, not ours to replace — and `ln -sfn`
    # would nest the link inside it rather than fail.
    if [ -d "$HOME/$d" ] && [ ! -L "$HOME/$d" ]; then
      warn "$HOME/$d is a real directory — move it into $SHARE, then re-run"
      continue
    fi
    mkdir -p "$SHARE/$d"
    ln -sfn "$SHARE/$d" "$HOME/$d"
  done
fi

# Publish what the sandbox reads. Its own script so a skill or shared-script edit
# can be published without the brew + stow work above.
"$PWD/scripts/deploy-runtime.sh"

# Wire the sandbox home to that copy. Unconditional, not guarded on "does it
# look wired": the links are only half of it — a change to agents/install.sh or
# to DIRS also has to be re-applied inside the sandbox, and no cheap stat sees
# that. It costs ~2.4s of `sv shell` round-trips and is idempotent.
if [ -d "$SHARE" ]; then
  "$PWD/scripts/sandvault-sync.sh"
fi

# Commit identity. The tracked ~/.gitconfig defaults to the personal address, and
# ~/.gitconfig.local adds a rule per employer org, keyed off the repo's remote
# (README, "Not tracked"). It holds the org name, so it cannot live in this repo.
if [ ! -f "$HOME/.gitconfig.local" ]; then
  warn "no ~/.gitconfig.local — work repos will commit as the personal address (fine if this machine has none)"
else
  # An include pointing at a file that does not exist is a silent no-op in git:
  # the rules read as installed and route nothing. Worth one stat each.
  awk -F= '/^[[:space:]]*path[[:space:]]*=/ {gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); print $2}' \
    "$HOME/.gitconfig.local" | while IFS= read -r inc; do
    [ -f "${inc/#\~/$HOME}" ] || warn "~/.gitconfig.local includes $inc, which does not exist"
  done
fi

# The things install.sh cannot do for you.
if [ -d "$SHARE" ]; then
  # Holds live PATs, so it is created by hand from inside sv shell (README,
  # "Not tracked").
  [ -f "$SHARE/user/.zshenv" ] || \
    warn "no $SHARE/user/.zshenv — gh is unauthenticated in the sandbox"
  # ~/brain is its own repo. The link above only makes the directory, so without
  # the clone the journal still works and is versioned by nothing.
  [ -d "$SHARE/brain/.git" ] || \
    warn "$SHARE/brain is not a checkout — clone your brain repo into it"
fi

ok "dotfiles installed — restart your shell (or: exec zsh)"
