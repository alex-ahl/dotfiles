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

- **Re-check git state before mentioning it, and only mention it if it's true.**
  After a commit handoff I usually commit right away, so a reading taken earlier
  in the turn is stale by the time I read your message — "still uncommitted" then
  reads as nagging about something I already did. Run `git status` at the moment
  you're about to say it. Genuinely uncommitted is worth one line; already
  committed is worth none.

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
  host-only repo. When you are sandboxed you cannot see it, and both editing an
  existing copy and adding a new one appear to work — the deployed tree is
  writable — but the next `scripts/deploy-runtime.sh` rebuilds it from the repo
  and your change is gone. Neither leaves a trace.
  If a change is needed there, don't patch the copy — write the proposed content
  to `~/handoffs/<slug>.md` (shared, the host account reads it) and hand me a
  paste-ready instruction naming the source path. Deployed → source:
  `~/.claude-account*/skills|commands/…` →
  `agents/shared/…`, `CLAUDE.md` → `agents/shared/AGENTS.md`,
  `~/.scripts/shared/…` → `scripts/shared/…`. Have it end with
  `scripts/deploy-runtime.sh` from the repo root — `agents/install.sh` only
  relinks the host account and leaves this copy stale, and `./install.sh` does
  the deploy but restows the whole home on the way past.

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

- **Don't change a config that governs the source without asking.** `tsconfig.json`,
  ESLint/Prettier, `package.json`, bundler and build config, test-runner config,
  `.editorconfig`, CI workflows. Tell me *why* — the problem the current config
  causes, in a sentence or two — and stop there. Don't volunteer *what* to change:
  naming the fix pre-empts a decision that is mine. If I ask, give the exact file,
  setting, and new value. This holds even when the change is the obvious way to
  make the task work.

- **Read `~/.claude-account*/DEV-MANIFEST.md` before writing, reviewing, or
  discussing code.** My coding rules live there, not here. Read the file rather
  than recalling it, and follow its own scoping rules.

- **Don't spawn subagents / background agents without approval.** Before
  launching any background or parallel agent work, say what you'd run and get an
  explicit go-ahead first.

- **Be brief.** Lead with the answer; cut preamble, hedging, and restating the
  question. Expand only when asked or when the task genuinely needs it.

- **Answer in this shape:** (1) one-line direct answer; (2) supporting detail
  only if needed; (3) one load-bearing caveat, only if it changes what the user
  would do. Default to bullets for the detail — I scan rather than read, and a
  paragraph hides its own structure. Prose only when the point is one thought
  that bullets would fragment.

- **Critique your own output before presenting it.** Check claims against
  evidence and catch your own errors. Surface a caveat only when it changes what
  the user would do — one line, no reflexive hedging.

- **Price the side effects you flag.** A risk, caveat, or side effect isn't
  reportable until you can name a concrete path to it — what someone does, in
  what order, that makes it happen — plus how bad it is when it does and how
  likely that sequence is. If you can't construct that scenario, say so; often
  it turns out the risk isn't real.

- **Routing what you learn** — before saving a durable fact, ask "would I want
  this in a different repo tomorrow?" Yes → it's a global rule/preference; put it
  in this file. No → it's project context; put it in per-project auto-memory.
