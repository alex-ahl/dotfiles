---
name: agent-md-refactor
description: Refactor a bloated AGENTS.md, CLAUDE.md, or similar agent instruction file into a minimal root plus linked topic files. Use when the user says their agent instructions are too long, asks to split, organize, or clean up AGENTS.md / CLAUDE.md, or wants progressive disclosure for their instructions.
---

# Agent MD refactor

Cut an agent instruction file down to what applies to *every* task, and move the rest into
linked topic files the agent loads only when it needs them.

**Ask before writing.** Never rewrite AGENTS.md or CLAUDE.md as a side effect. Propose the split
— the new root, the file list, and what you'd delete — and wait for explicit approval.

## 1. Find contradictions first

Before restructuring anything, look for rules that fight each other: conflicting style rules,
incompatible workflow steps, a general rule and a narrower one that contradicts it. Present each
pair verbatim and ask which wins, or whether both are conditional. Restructuring around a
contradiction just hides it.

## 2. Keep only the essentials at the root

The root file is what applies to 100% of tasks:

- one-sentence description of the project or machine
- package manager and non-standard commands, only where they differ from the default
- rules that must **override** default agent behaviour
- genuinely universal constraints

Everything else — language conventions, testing guidance, code style, framework patterns, git
workflow, documentation standards — is topic material.

## 3. Group the rest

Aim for 3-8 self-contained topic files, named `{topic}.md`: `code-style.md`, `testing.md`,
`git-workflow.md`, `architecture.md`, `security.md`. Not so granular that nothing has context,
not so broad that the file is a second dumping ground.

Root file, after:

```markdown
# <name>

<one sentence>

## Commands
- `<build>` / `<test>` / `<typecheck>`

## Guidelines
- [Code style](<dir>/code-style.md)
- [Testing](<dir>/testing.md)
- [Git workflow](<dir>/git-workflow.md)
```

A link is only progressive disclosure if the agent knows *when* to follow it. Say what each file
covers in the line that links it, so the trigger is visible without opening it.

## 4. Flag for deletion

Propose removing — don't remove silently:

| Delete when | Example |
|---|---|
| Redundant with the environment | "Use TypeScript" in a TS-only repo |
| Too vague to act on | "Write clean code" |
| Already default behaviour | "Use descriptive variable names" |
| Outdated | References a flag or API that's gone |

Verify before proposing deletion: a rule that names a file, script, or flag may be load-bearing —
check it still exists rather than assuming it's stale.

## Verify

Root under ~50 lines · every link resolves · no contradictions left · every surviving instruction
is specific enough to act on · nothing lost except what was explicitly flagged · each topic file
stands alone.

## Never

- **Never edit the instruction file without approval** — it governs every future session; a silent
  change is a silent change to the agent's behaviour everywhere.
- **Never delete a rule you can't explain** — an odd-looking rule usually encodes a past failure.
  Ask why it's there before proposing its removal.
- **Never split so far that the root loses a rule that must always apply** — an override that's
  one link away is an override that gets missed.
- **Never fragment into a dozen tiny files** — navigation cost replaces the bloat you removed.
