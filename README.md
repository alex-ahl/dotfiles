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
Aliases `wsg`, `cb`, `cwt`, `wtp` (in `.zshrc`) point here.

`wt-prune.sh` (`wtp`) — sweep all wsg sessions and clean up finished ones: a
branch with a merged PR (`gh`) or a gone upstream gets its worktree removed +
session killed; a regular (non-worktree) repo is switched back to the default
branch with the merged branch deleted, then the session killed. Skips the
default branch, dirty worktrees, and your current session. Dry-run + confirm
(`-y` to skip the prompt).

`wt-rehome.sh` — start a fresh worktree + wsg session from the current one,
carrying your in-progress work. Bound to `prefix + M` (prompts for the new
name). Behaviour depends on the current branch's PR state (`gh pr view`):
- **merged** → new worktree off the latest default branch; changes **move** to
  it; the old worktree + session are **torn down**.
- **not merged** (after `y/N` confirm) → new worktree off the **current HEAD**
  (carries the commits); changes are **copied**; the old worktree + session are
  **kept** intact.

Gitignored files (`.env`, caches) are copied across in both modes. Aborts
non-destructively if the default branch can't be fast-forwarded (merged path)
or the stash-pop conflicts.

## Not tracked (set up manually, contain secrets/state)

`~/.npmrc` (auth token), cloud/AI creds (`gcloud`, `gh`, `.codex`, `.gemini`, NuGet),
all `.claude` runtime state (sessions, projects, cache, history, `.claude.json`,
credentials), `.config/zellij`, `.config/opencode`, sol binary state, and the legacy
iTerm2 `~/git/scripts/workspace.sh`.
