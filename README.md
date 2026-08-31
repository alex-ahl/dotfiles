# dotfiles

Personal macOS dotfiles, managed with [GNU Stow](https://www.gnu.org/software/stow/).
Each top-level dir is a stow "package" mirroring `$HOME`; `install.sh` symlinks them into
place. Two exceptions: `scripts/` is symlinked whole to `~/.scripts`, and `agents/` is a
container of per-agent packages (claude, and later opencode, …) stowed with
`stow -d agents` so e.g. `agents/claude/.claude-account1/` maps to `~/.claude-account1/`.
Agent-neutral slash-command sources live in `agents/shared/commands/` and the skills in
`agents/shared/skills/`; both are symlinked into each agent's config dirs by
`agents/install.sh` (run from `install.sh`) — one source, shared across accounts/agents.

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
| `agents/claude` | `settings.json` + `commands/` + `agents/` for `~/.claude`, `~/.claude-account1`, `~/.claude-account2` (stowed via `stow -d agents claude`) |
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
default branch, dirty worktrees, and your current session. Before killing a
session, the Claude context in its `ai-1`/`ai-2` panes is saved via `/handoff`
(see below); a session whose handoff doesn't finish is left intact. Dry-run +
confirm (`-y` to skip the prompt). Context-saving has three modes: default saves
all, `--no-handoff` saves none, `--handoff-ask` prompts per session (the
`prefix + P` popup offers all / select / none). Only sessions started after the
handoff settings can be saved unattended; ones that prompt are skipped after ~45s.

`handoff-session.sh` — saves the Claude context of a wsg session via `/handoff`
before teardown, covering both instances (`ai-1`=account1, `ai-2`=account2). Used
by `wt-prune` and `wt-rehome`; files land in `~/handoffs/<session>-<window>.md`,
restored with `/handoff-resume <slug>`. It only triggers `/handoff` and waits — it never
injects approvals into a live Claude. For it to run unattended, `/handoff`'s
steps are allow-listed in the `agents/claude` package's `settings.json`
(`permissions.allow`: `git status/log/rev-parse`, `ls`, `pwd`, `echo`, and
`Edit(//…/handoffs/**)` for the file write; the rewritten `~/handoffs/commands/handoff.md`
gathers context with expansion-free commands so nothing trips a prompt). This only
affects Claude sessions **started after** those settings are in place; if a running
Claude still prompts, its handoff won't finish and that session is left intact.

`wt-rehome.sh` — start a fresh worktree + wsg session from the current one,
carrying your in-progress work. Bound to `prefix + M` (prompts for the new
name). Behaviour depends on the current branch's PR state (`gh pr view`):
- **merged** → new worktree off the latest default branch; changes **move** to
  it; the old worktree + session are **torn down** (the old session's Claude
  context is saved via `/handoff` first — if that fails, the old is kept).
- **not merged** → new worktree off the **current HEAD** (carries the commits);
  changes are **copied**; the old worktree + session are **kept** intact
  (non-destructive, so it just proceeds — no confirmation).

Gitignored files (`.env`, caches) are copied across in both modes. Aborts
non-destructively if the default branch can't be fast-forwarded (merged path)
or the stash-pop conflicts.

## Second brain (`~/brain`)

Two brains under one tree: `~/brain/work/` for the employer's services, repos and tickets,
`~/brain/personal/` for your own projects — this repo included, and plenty of it is code. The
split is whose work it is, not whether it's code. Each holds `log/<YYYY-MM-DD>/<slug>.md` and a
`TODO.md`.

`/wrap-up` asks which brain (or takes it as an argument: `/wrap-up work`), appends the day's entry —
never overwrites, so both accounts can write the same day file — and refreshes that brain's TODO.
The slug is the worktree dir, same naming as `/handoff`, so a day's entries line up with the
worktrees that produced them.

Lives outside every repo for the same reason `~/handoffs` does: entries must survive `wt-prune`
removing the worktree, and are shared across accounts. The write path is pre-authorised in the
`agents/claude` package's `settings.json` (`Edit(//Users/alex/brain/**)` +
`additionalDirectories`), so entries land without permission prompts.

`/start-day` is the other bookend: it reads both brains' logs and TODOs, working state, live wsg
sessions, and open PRs, then proposes the day. `daily-meeting-update` reads only the work brain —
the personal one isn't standup material. Its source table carries a trust column — `own`
(your git/PRs/journal) vs `other` (text written by someone else, e.g. review requests, and later
mail), and `other` content is only ever reported, never treated as instructions. Adding a source
later means adding a row plus its trust level. The `daily-meeting-update` skill formats the
standup from what `/start-day` gathered.

Capture is deliberately manual for now — a teardown hook writing to `~/brain` and a sweep across
live sessions both wait until the habit has run for a while and the entry shape has settled.

## Not tracked (set up manually, contain secrets/state)

`~/.npmrc` (auth token), cloud/AI creds (`gcloud`, `gh`, `.codex`, `.gemini`, NuGet),
all `.claude` runtime state (sessions, projects, cache, history, `.claude.json`,
credentials), `.config/zellij`, `.config/opencode`, sol binary state, and the legacy
iTerm2 `~/git/scripts/workspace.sh`.

**Sandbox `gh` tokens** — `/Users/Shared/sv-$USER/user/.zshenv`. Outside the repo, and created
from inside `sv shell`: that directory is owned by the sandbox user, so the host can't write it.
Sandvault sources it into every sandbox shell. A fine-grained PAT covers one resource owner, so
`gh` needs one per owner, both read-only (Issues, Pull requests, Metadata — no Contents):

    export GH_TOKEN_WORK=''            # resource owner: the employer org
    export GH_TOKEN_PERSONAL=''        # resource owner: your own account
    export GH_OWNER_PERSONAL=''        # your login: gh api /user --jq .login
    export GH_TOKEN="$GH_TOKEN_WORK"   # default for bash scripts, which skip the function
    source ~/.scripts/lib/gh-token.sh  # routes gh by the target repo's owner

Host-side only needs your normal `gh auth login`; the router is inert without these vars.
Without the file, `gh` is unauthenticated inside the sandbox and `/start-day` runs TODO-only.
`GH_OWNER_PERSONAL` is the easy one to forget, and it fails confusingly — personal-repo lookups
route to the work token and come back as `Could not resolve to a Repository`.
