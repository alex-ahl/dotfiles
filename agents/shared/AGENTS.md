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

- **An egress block is not a real 403.** Policy shows as the request dying before
  any reply arrives — `Socket is closed`, `CONNECT tunnel failed`, curl exit 56,
  a bare connection reset — because the sandbox's allowlist refused the host and
  there's no prompt to say so. A 403 that arrives *as the server's answer* is the
  service saying no; handle it normally. On a block: stop, name the host and why
  you needed it, and give me the command that adds it. Never retry and never
  route around it via a mirror. If the refused host isn't the one you requested
  (a redirect, a sub-resource), say so rather than guessing. The allowlist is
  mine to edit — that's the point.

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
