# Dev manifest

Coding rules and opinions I want followed in any repo — my standards, not industry
consensus. Read this file before writing, reviewing, or discussing code, and read
it rather than working from memory of it: it changes as rules are added.

Deployed like the global instructions — `agents/install.sh` links it into each
agent config dir, so `~/.claude-account*/DEV-MANIFEST.md` resolves the same on the
host and inside the sandbox.

## How to apply

- **Language-agnostic sections** — `General`, `Testing` — apply always, whatever
  the stack.
- **Language or framework sections** apply only when the work is in that language
  or framework.
- **A more specific rule wins** where it contradicts a general one, and only for
  that context.
- **A section's intro is part of its rules**, not decoration.
- **A repo's own documented standards win** where they conflict — `CONTRIBUTING.md`,
  `CODING_STANDARDS.md`, a project `CLAUDE.md`, or a linter config that encodes the
  house style. This file is mine, not the team's, and a shared repo is not the place
  to enforce it. But never drop a rule silently: name the rule being set aside and
  the document that overrides it, so the conflict is visible rather than resolved
  behind my back.

## Adding a rule

Propose it as a bullet under the best-fit section and wait for an explicit yes —
same contract as the global instructions. Say which section, and why the rule is
general rather than a one-off.

Create a new section only when its first rule exists. Empty headings are noise,
and a section per language invites filling it for symmetry's sake.

## General

- **Keep comments terse but clear** — the shortest wording that's still
  understandable; terseness never at the cost of comprehension. Don't restate
  self-explanatory code; comment for what the code can't say (a constraint, a
  gotcha, the *why*). **Exception:** shell / config scripts (dotfiles, setup
  scripts) may carry explanatory comments, still terse. Match the comment density
  of the surrounding file.

- **A comment explains why the code is *this way*, not why it exists.**
  Constraints, gotchas and rejected alternatives belong next to the code; the
  problem that motivated the change belongs in the commit message. Test: if the
  comment would be equally true of a completely different implementation, it
  isn't a comment. When an edit comes from a handoff or a plan, its "Why"
  section stays behind.

- **One job per function.** A function that runs several steps in sequence
  becomes one function per step, and the caller reads as the pipeline. Split by
  responsibility, not line count.

- **Shared rules get their own module.** When two parts must agree (training and
  inference, client and server), the shared code lives in a module both import.
  One command never imports another command's module.

- **Shared mutable state goes in a class.** No long functions whose nested
  closures share mutable state.

- **A refactor proves behaviour unchanged.** Run old and new on the same seeded
  input and compare the output, on top of the tests passing.

- **Checks from day one.** Formatter, linter, type checker and a complexity
  limit, with CI running them and the tests, before the code grows.

## Testing

_No rules yet._

## Python

- **Module per topic, not file per class.** Split a module when its parts change
  for different reasons, not because it got long.

- **Starter config.** `pyproject.toml`: `[tool.ruff] line-length = 120`,
  `[tool.ruff.lint] extend-select = ["C90", "PLR0912", "PLR0915"]`,
  `[tool.basedpyright] typeCheckingMode = "standard"`. CI runs `ruff check`,
  `ruff format --check`, `basedpyright` and the tests. In a new project this
  setup is pre-approved; changing it later still needs asking.

- **Typed signatures and data shapes.** Type every function signature. Data
  passed between modules gets a `TypedDict` or dataclass, not a bare `dict`.

- **`logging`, not `print`, in long-running processes.** All commands report
  errors the same way.

- **Pass in a `random.Random`** rather than using the global `random`, so runs
  can be reproduced.
