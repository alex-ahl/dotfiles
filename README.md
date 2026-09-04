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
git clone --recurse-submodules git@github.com:<you>/dotfiles.git ~/.config/dotfiles
cd ~/.config/dotfiles
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
brew bundle dump --file=~/.config/dotfiles/Brewfile --force --describe
```

Install/upgrade from it: `brew bundle --file=~/.config/dotfiles/Brewfile`.
Remove anything not in the Brewfile: `brew bundle cleanup --file=~/.config/dotfiles/Brewfile`.

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
| `agents/claude` | `settings.json` for `~/.claude`, `~/.claude-account1`, `~/.claude-account2` (stowed via `stow -d agents claude`), plus `.claude/agents/`. `commands/`, `skills/` and `CLAUDE.md` are symlinked by `agents/install.sh`, not stowed — and only into the two account dirs, so plain `~/.claude` gets none of them |
| `nvim`     | `~/.config/nvim` (git submodule → `alex-ahl/nvim`)          |
| `scripts`  | `~/.scripts` (symlinked dir, on PATH-style use)             |

## Scripts (`~/.scripts`)

On the host, a symlink to this repo's `scripts/`. Inside the sandbox, a symlink to the deployed
copy — see "Where this repo lives".

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
`Edit(//…/handoffs/**)` for the file write; the rewritten `agents/shared/commands/handoff.md`
gathers context with expansion-free commands so nothing trips a prompt). This only
affects Claude sessions **started after** those settings are in place; if a running
Claude still prompts, its handoff won't finish and that session is left intact.

`agent-relaunch.sh` — respawn the current agent pane with its conversation
resumed, bound to `prefix + R`. Agent-agnostic: the resume command comes from
the profile's `agent_continue_cmd` (`claude --continue` for the default). That
string lives only in the profile, so a pane whose agent exited can't rebuild
itself, and re-running `wsg` would boot cold. Mainly for approving a domain: srt
reads its allowlist at startup, so the running pane keeps the old policy until
it is respawned. Reads the launch context from the session's `@wsg_agent` /
`@wsg_egress` options — set at scaffold time, because `run-shell` sees the
server's environment and `sv`'s `env -i` keeps `WSG_*` out of the pane. Sessions
older than those options are refused rather than relaunched with egress
filtering silently dropped; stamp one by hand instead of recreating it:

```sh
S=$(tmux -L wsg display-message -p '#{session_name}')
tmux -L wsg set-option -t "$S" @wsg_agent claude
tmux -L wsg set-option -t "$S" @wsg_egress 1   # 0 to run the session unfiltered
```

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
iTerm2 `~/git/scripts/workspace.sh`. Nothing here points at it: it lives in the share, so the
sandbox can rewrite it, and anything host-executed there is an escape.

**Sandbox `gh` tokens** — `/Users/Shared/sv-$USER/user/.zshenv`. Outside the repo, and created
from inside `sv shell`. Owned by the sandbox user — but note the host can read *and* write it
anyway: the share's inherited ACL grants `group:sandvault-$USER` write, and this account is in that
group, so the `0600` on it is not the protection it looks like. It holds live PATs.
Sandvault sources it into every sandbox shell. A fine-grained PAT covers one resource owner, so
`gh` needs one per owner, both read-only (Issues, Pull requests, Metadata — no Contents):

    export GH_TOKEN_WORK=''            # resource owner: the employer org
    export GH_TOKEN_PERSONAL=''        # resource owner: your own account
    export GH_OWNER_PERSONAL=''        # your login: gh api /user --jq .login
    export GH_TOKEN="$GH_TOKEN_WORK"   # default for bash scripts, which skip the function
    source ~/.scripts/shared/gh-token.sh  # routes gh by the target repo's owner

Both accounts can write the share because `sv` applies an inheriting ACL
(`group:sandvault-$USER allow …write…`) across it, and macOS evaluates ACLs ahead of the mode
bits. The mode bits there are therefore decorative: a 644 file in the share is still writable by
the sandbox.

The ACL is applied at build time and inherited by anything *created* inside the share afterwards.
It is not inherited by anything **moved** in — `mv` is a rename and carries the source's ACLs,
which is how ~70 repos under `git/legacy/` ended up bare. After bulk-moving anything in, run
`sv -r build` and check with:

```sh
for d in /Users/Shared/sv-$USER/git/*/; do
  ls -lde "$d" | grep -qE "sandvault-$USER (inherited )?allow" || echo "no ACL: $d"
done
```

Host-side only needs your normal `gh auth login`; the router is inert without these vars.
Without the file, `gh` is unauthenticated inside the sandbox and `/start-day` runs TODO-only.
`GH_OWNER_PERSONAL` is the easy one to forget, and it fails confusingly — personal-repo lookups
route to the work token and come back as `Could not resolve to a Repository`.

## Where this repo lives (`~/.config/dotfiles`)

Private to `$USER`, not in the sandvault share. `/Users/$USER` is `0750`, so the sandbox account
cannot traverse it at all — which means nothing the host executes is writable by the agent.

That matters because *everything* here is host-executed: `~/.zshenv` is sourced by every host
shell, `tmux.conf` binds keys that `run-shell` as you, and `status-right` runs `agent-badge.sh`
and `git-status.sh` on every refresh — unattended, no keystroke. Anything host-executed that lives
in the share is writable by `sandvault-$USER` and therefore an escape: sandvault's separate UID is
the boundary POSIX enforces, and the host's own execution surface has to stay outside the shared
tree for it to mean anything.

The sandbox still needs three things from here, so `install.sh` deploys them outward as **copies,
never symlinks** — an agent write in the share must not reach anything the host runs:

| deployed to | what | read by |
| --- | --- | --- |
| `/Users/Shared/$USER-policy/srt-settings.json` | the egress allowlist | srt, as `sandvault-$USER` |
| `/Users/Shared/sv-$USER/agent-runtime/scripts/shared` | the three scripts the sandbox calls | `repo-pointer`, `fileSuggestion`, the gh router |
| `/Users/Shared/sv-$USER/agent-runtime/agents` | skills, commands, `settings.json` | Claude, inside the sandbox |

`scripts/shared/` is the boundary: only what the sandbox actually calls lives there, and only that is
deployed — the rest of `scripts/` is host-only tmux tooling with no business in the share. The relative
path is identical on both sides (`~/.scripts/shared/…`), so one `settings.json` works for both.

`sandvault-sync.sh` wires the sandbox home to that `agent-runtime` dir; the host keeps stowing straight from
the repo. The cost is a deploy step: **editing or adding a skill or a script needs `./install.sh`
before the sandbox sees it.** The trade is deliberate — live edits were the escalation path.

Working on this repo therefore happens on the host. The workspace picker (`prefix + N`) already
lists `~/.config/*`, so `~/.config/dotfiles` shows up on its own, and `_agent_sandbox`
(`scripts/agents.d/claude.sh`) launches the agent unsandboxed for any path outside the share —
`sv shell` would fail there anyway, since the sandbox cannot reach it. `agent-badge.sh` labels such
a pane `host`, which is the honest signal: that agent has your keys and your `gh` token.

## Egress filtering (`WSG_EGRESS`)

Sandvault bounds the filesystem but not the network, so on its own the sandbox has unrestricted
outbound. Every agent pane is therefore wrapped in
[srt](https://www.npmjs.com/package/@anthropic-ai/sandbox-runtime) with an allow-only domain list —
the scaffolders default `WSG_EGRESS` to `1`, and `WSG_EGRESS=0` opts a session out. Sessions
scaffolded before that default keep their stamp and stay unfiltered until recreated.

srt is not only the allowlist: its `filesystem` rules are what deny writes to `.git/config`,
`.git/hooks` and the rc files, so a pane running without it loses those too. That is why this is
on by default rather than opt-in.

Needs srt installed **on the host**, with Homebrew's npm rather than nvm's — nvm installs under
`~/.nvm`, which the sandbox account can't read:

```sh
/opt/homebrew/bin/npm install -g @anthropic-ai/sandbox-runtime
```

It runs under `sv -x`, because seatbelt doesn't nest: srt is `sandbox-exec` too, so sandvault's own
profile has to be off for srt's to apply. Sandvault still supplies the separate UID, which is the
boundary POSIX enforces; srt supplies the policy.

Adding a domain is deliberately yours. srt does not read this repo — `install.sh` deploys the
settings file to `/Users/Shared/$USER-policy/`, owned by you and 644. That directory sits outside
the sandvault share, so `sv -r`'s ACL walk never re-grants the sandbox group write on it, and
`/Users/Shared` is sticky, so the sandbox account cannot replace it either.

When the agent reports a blocked host, add it, commit, and re-run `install.sh` — the commit is the
approval record, the deploy is what srt actually reads:

```sh
jq '.network.allowedDomains |= (. + ["example.com"] | unique)' \
  scripts/lib/srt-settings.json > /tmp/s && mv /tmp/s scripts/lib/srt-settings.json
./install.sh
```

srt reads its settings once at startup, so a new domain applies to the next pane, not a running one.
Deliberately: `--control-fd` would hot-swap the allowlist live (the proxy re-reads
`network.allowedDomains` per request), but it needs a feeder process holding a readable fd for the
pane's life, which is the runtime protocol a commit-and-relaunch exists to avoid — and srt spawns
its child with inherited stdio, so a read-write control fd would likely hand the agent the
self-approval the deployed copy denies it. Relaunching costs one `prefix + R`
(`agent-relaunch.sh`), which brings the conversation back with it.

A block does return an HTTP 403 — the *proxy's*, not the server's. It answers the CONNECT with
`403` plus `X-Proxy-Error: blocked-by-allowlist`, so the tunnel never opens: `CONNECT tunnel
failed, response 403` and exit 56 from curl, `Socket is closed` from WebFetch. A real 403 arrives
inside an established connection, as the answer to the request itself. `srt -s
scripts/lib/srt-settings.json --debug <cmd>` names the refused host (`--debug` just sets
`SRT_DEBUG`, which is the only thing that makes srt log at all — and it logs to stderr, shared with
the sandboxed child).

`filesystem.denyWrite` carries six entries, and they are **absolute paths on purpose**. srt
resolves a relative pattern against the pane's startup cwd (`normalizePathForSandbox`), so
`**/.zshenv` only ever matched below whatever directory the pane happened to start in — and
`wt-session.sh` starts panes in the worktree. The same bug silently disabled srt's own built-in
`**/.git/config` and `**/.git/hooks/**` for every repo but the one you were standing in. Absolute
patterns skip that resolution.

The entries cover `.zshenv` (srt's built-in list has `.zshrc`, `.zprofile` and `.profile` but not
the one rc file *every* `zsh -c` sources), plus `config` and `hooks` under both `.git` and `.bare`
— srt only knows the conventional layout, and this machine's repos are mostly bare-with-worktrees.

Two settings are load-bearing and non-obvious: `allowPty` (without it a TUI can't enter raw mode
and mouse movement types escape sequences) and `enableWeakerNetworkIsolation` (Go binaries verify
TLS through `trustd`, so `gh` fails on every request without it). Clipboard is *not* granted:
copy-to-clipboard from inside the sandbox would need `allowMachLookup` for the pasteboard, which
also hands the agent `pbpaste`. Shift-drag selects at the terminal instead.

**Claude's OAuth token lives in a file here, not the keychain.** Under srt the keychain is
readable but not writable — `security find-generic-password` succeeds, `add-generic-password`
fails with `UNIX[Operation not permitted]`. So `/login` falls back to
`~/.claude-account$N/.credentials.json`, while startup still *reads* the keychain first. A
credential written by a non-srt pane therefore shadows every later login: the pane reads the old
token, refreshes it, gets `401 OAuth access token has been revoked`, and wipes the file it just
wrote. Delete the stale items once and the fallback takes over:

    sv shell -- security delete-generic-password -s "Claude Code-credentials-<hash>"

`sv shell`, not `sv -x` — srt is what can't write. The `<hash>` suffixes one item per config dir;
`sv shell -- security dump-keychain ~/Library/Keychains/sandvault.keychain-db` lists them.

The trap is the delay: access tokens last 8 hours, so a pane keeps working all morning on a token
minted before the shadowing existed, then fails hours later looking like a network problem. Check
`accessTokenLen` in `.credentials.json` — cleared within a second of pane start means the keychain
is being read, not the file. (`allowMachLookup` may explain the read/write split; granting it for
the keychain is untested, and it is the same knob the clipboard note above declines.)
