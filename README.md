# dotfiles

Personal macOS dotfiles, managed with [GNU Stow](https://www.gnu.org/software/stow/).
Each top-level dir is a stow "package" mirroring `$HOME`; `install.sh` symlinks them into
place. `scripts/` is the exception — it's symlinked whole to `~/.scripts`.

## Install (new machine)

```sh
# 1. Homebrew (everything else comes from the Brewfile)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 2. Clone + install. install.sh runs `brew bundle` (taps, formulae, casks,
#    including stow), inits the nvim submodule, and stows everything.
git clone --recurse-submodules git@github.com:<you>/dotfiles.git ~/git/dotfiles
cd ~/git/dotfiles
./install.sh          # set NO_BREW=1 to skip the brew bundle step
exec zsh
```

Not covered by Homebrew (install separately if you want them):

```sh
# oh-my-zsh + powerlevel10k
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
  "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
# nvm, Rust (referenced by .zshrc)
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

Also enable iTerm2 shell integration if you use iTerm2 (`.zshrc` sources it if present).

## Homebrew packages (`Brewfile`)

The `Brewfile` lists all taps, formulae, casks, and Mac App Store apps. Refresh it after
installing/removing packages, then commit:

```sh
brew bundle dump --file=~/git/dotfiles/Brewfile --force --describe
```

Install/upgrade from it: `brew bundle --file=~/git/dotfiles/Brewfile`.
Remove anything not in the Brewfile: `brew bundle cleanup --file=~/git/dotfiles/Brewfile`.

## What's tracked

| Package    | Links to                                                    |
|------------|-------------------------------------------------------------|
| `zsh`      | `~/.zshrc .zshenv .zprofile .profile .p10k.zsh`             |
| `git`      | `~/.gitconfig`, `~/.config/git/ignore`                      |
| `ssh`      | `~/.ssh/config` (no keys)                                   |
| `harlequin`| `~/.harlequin.toml`                                         |
| `docker`   | `~/.docker/config.json`, `~/.docker/daemon.json` (no auths) |
| `ghostty`  | `~/.config/ghostty/config`, `~/.config/ghostty/base.conf`   |
| `tmux`     | `~/.config/tmux/tmux.conf`                                  |
| `karabiner`| `~/.config/karabiner/karabiner.json`                        |
| `worktrunk`| `~/.config/worktrunk/config.toml`                           |
| `sol`      | `~/.config/sol/config.json`                                 |
| `claude`   | `settings.json` + `commands/` + `agents/` for `~/.claude`, `~/.claude-account1`, `~/.claude-account2` |
| `nvim`     | `~/.config/nvim` (git submodule → `alex-ahl/nvim`)          |
| `scripts`  | `~/.scripts` (symlinked dir, on PATH-style use)             |

## Scripts (`~/.scripts`)

`clone-bare.sh`, `check-worktrees.sh`, and the ghostty/tmux workspace helpers
(`start-tmux.sh`, `workspace.sh`, `wt-session.sh`, `kill-session.sh`, `git-status.sh`).
Aliases `wsg`, `cb`, `cwt` (in `.zshrc`) point here.

## Not tracked (set up manually, contain secrets/state)

`~/.npmrc` (auth token), cloud/AI creds (`gcloud`, `gh`, `.codex`, `.gemini`, NuGet),
all `.claude` runtime state (sessions, projects, cache, history, `.claude.json`,
credentials), `.config/zellij`, `.config/opencode`, sol binary state, and the legacy
iTerm2 `~/git/scripts/workspace.sh`.
