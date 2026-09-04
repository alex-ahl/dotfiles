# Global agent instructions

Applies to any AI coding agent (Claude Code, opencode, …) on this machine.
Deployed into each agent's global-instructions location by `agents/install.sh`
(for Claude, symlinked as `~/.claude-account*/CLAUDE.md`).

- **Ask before editing this file.** Never write to this file (or the deployed
  `CLAUDE.md`) as a side effect of another task. Propose the exact wording and
  wait for explicit approval before adding, changing, or removing a rule here.

- **Git is the user's to drive.** Staging needs no permission: `git add` and
  `git restore --staged` are yours to run freely. Never run `git commit` or
  `git push`, and never create a branch (`git branch` / `checkout -b` /
  `switch -c`) without asking first. `git reset` needs asking too — it silently
  discards staging I built by hand. Leave committing, pushing, and branching to
  the user. Applies in every repo, and overrides any skill/workflow step that
  would commit or branch (e.g. executing-plans, finishing-a-development-branch).

- **An egress block is not the service saying no.** The sandbox's allowlist
  refuses a host by answering the CONNECT itself — HTTP 403 with
  `X-Proxy-Error: blocked-by-allowlist` — so the tunnel never opens:
  `CONNECT tunnel failed, response 403` and exit 56 from curl, `Socket is
  closed` from WebFetch, a bare reset. **The 403 is not the discriminator**;
  the proxy sends one too. A real refusal arrives *inside an established
  connection*, as the answer to your request, carrying the service's own body.
  On a block: stop, name the host and why you needed it, and give me the
  command that adds it. Never retry and never route around it via a mirror.
  If the refused host isn't the one you requested (a redirect, a sub-resource),
  say so rather than guessing. The allowlist is mine to edit — that's the
  point. It applies to the next pane, not this one, so after I add a host wait
  for the relaunch (`prefix + R`) rather than reading the same 403 as a new
  failure.

- **Dotfiles live outside the sandbox.** `~/.scripts/*` and the skills and
  commands under `~/.claude-account*/` are deployed copies; the source is a
  host-only repo. When you are sandboxed you cannot see it, and editing an
  existing copy appears to work and is silently reverted by the next
  `install.sh`; adding a new one appears to do nothing. Neither leaves a trace.
  If a change is needed there, don't patch the copy — write the proposed content
  to `~/handoffs/<slug>.md` (shared, the host account reads it) and hand me a
  paste-ready instruction naming the source path. Deployed → source:
  `~/.claude-account*/skills|commands/…` →
  `agents/shared/…`, `CLAUDE.md` → `agents/shared/AGENTS.md`,
  `~/.scripts/shared/…` → `scripts/shared/…`. Have it end with `./install.sh`
  from the repo root — `agents/install.sh` only relinks the host account and
  leaves this copy stale.

- **Don't prefix shell commands with `cd <dir> &&` or `git -C <dir>` when already
  working in that repo** — run git and other tools in the current working
  directory (the shell cwd persists), so they match the read-only allowlist
  instead of prompting. Allowlist rules are prefix matches, so `git -C <dir>
  status` doesn't match a `git status` rule.

- **Don't create spec / plan / brainstorming files on your own.** Some skills and
  workflows (e.g. Superpowers brainstorming, writing-plans) normally write — and
  commit — a design spec or implementation plan; skip writing those files and
  keep the thinking in the conversation. Only produce such a document when I
  explicitly run a command that asks for one, and put it where that command says.
  This overrides any skill step that would write these files.

- **Keep comments terse but clear** — the shortest wording that's still
  understandable; terseness never at the cost of comprehension. Don't restate
  self-explanatory code; comment for what the code can't say (a constraint, a
  gotcha, the *why*). **Exception:** shell / config scripts (dotfiles, setup
  scripts) may carry explanatory comments, still terse. Match the comment density
  of the surrounding file.

- **Don't spawn subagents / background agents without approval.** Before
  launching any background or parallel agent work, say what you'd run and get an
  explicit go-ahead first.

- **Be brief.** Lead with the answer; cut preamble, hedging, and restating the
  question. Expand only when asked or when the task genuinely needs it.

- **Answer in this shape:** (1) one-line direct answer; (2) supporting detail
  only if needed; (3) one load-bearing caveat, only if it changes what the user
  would do.

- **Critique your own output before presenting it.** Check claims against
  evidence and catch your own errors. Surface a caveat only when it changes what
  the user would do — one line, no reflexive hedging.

- **Routing what you learn** — before saving a durable fact, ask "would I want
  this in a different repo tomorrow?" Yes → it's a global rule/preference; put it
  in this file. No → it's project context; put it in per-project auto-memory.
