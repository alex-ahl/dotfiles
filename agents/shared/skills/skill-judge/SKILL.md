---
name: skill-judge
description: Check a skill before you rely on it — spec compliance, whether its content earns its tokens, and whether it actually changes behaviour. Use when writing, reviewing, auditing, or trimming a SKILL.md, or when asked whether a skill is worth keeping.
---

# Skill judge

Three passes: what the format requires, what the content is worth, and whether it changes
anything. Only the third is evidence; the first two are checks.

## 1. Spec — mechanical, from the Agent Skills format

- Valid frontmatter; `name` lowercase, hyphens, ≤64 chars, matching the directory.
- `description` answers **what** it does, **when** to use it, and carries the words a user would
  actually type. Agents see only descriptions when deciding what to load, so a vague one means
  the skill never fires — excellent content behind it is dead weight.
- Body under ~500 lines, ideally under 300. Heavier material goes in `references/`.
- Every `references/` file has an explicit trigger at the step that needs it, and a "do not load"
  where over-loading is the risk. A reference nothing triggers is never read.

## 2. Content — sort every line into one of three

- **Knowledge** — true in any repo, for anyone ("inspect before staging", "don't commit
  secrets"). The model has it. Delete.
- **Preference** — a choice among things it already knows (50-char subjects; Conventional
  Commits; three lessons, not ten). Keep, one line each. You're picking a branch, not teaching.
- **Local fact** — only true here: the tools in use, the directory layout, the constraints of
  this machine, the rule the user gave you. Keep all of it. This is the skill.

A skill that is mostly Knowledge is a skill you can delete. A skill with no Local fact and no
Preference has nothing to say.

## 3. Judgement — what no spec checks

- Is there a NEVER list, and is each entry specific enough to prevent something? "Be careful"
  prevents nothing; "never `git add -A`, it sweeps in work you can't describe" does.
- Does each NEVER carry its reason? The reason is what makes it survive contact with a case the
  author didn't foresee.
- Is the freedom level matched to the fragility? Ask what breaks if the agent gets it wrong.
  Creative work gets principles; irreversible operations get exact steps.
- Would someone who does this daily recognise it as their hard-won knowledge, or as advice?

## 4. Evidence — ablate it

Everything above is opinion, including yours about your own writing. The one honest test: run the
task **without** the skill and compare. What the agent did anyway was Knowledge. What only
happened with the skill loaded is what the skill is worth.

Do this for skills you rely on. Reach for it whenever the argument for keeping one has become a
discussion about how well written it is.

## Common failure patterns

- **The tutorial** — explains basics. **The dump** — everything in the body, no layering.
- **The orphan reference** — a `references/` file nothing triggers.
- **The vague warning** — "be careful" instead of a specific NEVER plus its reason.
- **The invisible skill** — good body, weak description, never fires.
- **The wrong location** — "when to use this" in the body, read too late to matter.

## Never, when judging

- **Never reward polish** — formatting is not knowledge.
- **Never let length impress you** — 40 focused lines beat 500 padded ones.
- **Never score your own skill and call it evidence** — you can't tell which of your own
  paragraphs the model already knew. Sort by Knowledge/Preference/Local fact instead, which asks
  a question you *can* answer, or ablate.
- **Never forgive redundancy** as "helpful context".
