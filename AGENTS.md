# Working in this repo

Dotfiles for a macOS host that runs coding agents in a sandbox (sandvault for the
UID boundary, srt for egress *and* filesystem denials). The deploy model is not
visible from the tree — read "Where this repo lives" and "Egress filtering" in
the README before changing anything under `scripts/` or `agents/`.

## Four things that will catch you out

- **Nothing here is live for the sandbox.** The sandbox account cannot read
  `/Users/$USER` (0750). It sees deployed *copies* under
  `/Users/Shared/sv-$USER/agent-runtime/`, rebuilt by `./install.sh`. Edit or add
  a skill or a shared script and a sandboxed pane keeps running the old one until
  then — if a change appears to have no effect, this is why.

- **`scripts/shared/` is a boundary, not a folder.** Only what the sandbox calls
  lives there, and only that is deployed: `repo-resolve.sh` (repo-pointer skill),
  `repo-file-suggestion.sh` (`fileSuggestion` in `settings.json`), `gh-token.sh`
  (the sandbox's `.zshenv`). A new script a skill invokes must go there. The rest
  of `scripts/` is host-only tmux tooling. The relative path is deliberately the
  same on both sides: `~/.scripts/shared/…`.

- **The srt policy is deployed too.** It is not only an allowlist — its
  `filesystem.denyWrite` is what stops the sandbox writing `.git/config`,
  `.git/hooks` and the rc files, and those patterns are absolute because srt
  resolves relative ones against the pane's startup cwd. srt reads
  `/Users/Shared/$USER-policy/srt-settings.json`, not this repo. Adding a domain
  is: edit `scripts/lib/srt-settings.json`, commit, `./install.sh`, then
  `prefix + R` — srt reads its settings once at startup, so a running pane keeps
  the old policy. The deployed copy is not writable by the sandbox; that is the
  point.

- **An agent working in this repo is unsandboxed.** The tree is host-only by
  design, so the pane editing it runs as the host user, with its ssh keys and
  write-capable `gh` token. `agent-badge.sh` labels such a pane `host`. Everything
  here is executed by the host — `.zshenv`, `tmux.conf`, the status-bar scripts —
  so treat edits accordingly.

## Where things live

| path | who runs it | reaches the sandbox |
| --- | --- | --- |
| `scripts/shared/` | both | yes, deployed |
| `scripts/`, `scripts/lib/`, `scripts/agents.d/` | host, via tmux bindings | no |
| `agents/` | Claude, both accounts | yes, deployed |
| `scripts/lib/srt-settings.json` | srt | source only — deployed to `$USER-policy` |
| `zsh/`, `tmux/`, `git/`, `ssh/`, `nvim/`, … | host | no, stowed into `$HOME` |

## Don't

- Run `./install.sh` unasked. It restows the user's entire home and runs
  `brew bundle`; it is theirs to trigger.
- Assume a `scripts/` edit is testable in a sandboxed pane without a deploy.
- Add a package to the `stow` list for an app that rewrites its own config —
  see the `sol` block in `install.sh` for why.
