# Global agent instructions

Applies to any AI coding agent (Claude Code, opencode, …) on this machine.
Deployed into each agent's global-instructions location by `agents/install.sh`
(for Claude, symlinked as `~/.claude-account*/CLAUDE.md`).

- **Never run `git commit` or `git push`.** Make and stage changes, but leave
  committing and pushing to the user — they commit their own work. This applies
  in every repo, and overrides any skill/workflow step that would commit.

- **Don't prefix shell commands with `cd <dir> &&` when already working in that
  repo** — run git and other tools in the current working directory (the shell
  cwd persists), so they match the read-only allowlist instead of prompting.

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
