---
name: skill-judge
description: Evaluate Agent Skill design quality — scores a SKILL.md across eight dimensions and returns actionable fixes. Use when reviewing, auditing, improving, or writing SKILL.md files and skill packages, or when asked whether a skill is any good.
---

# Skill judge

Evaluate a skill against what actually makes skills work.

## The core formula

> **Good skill = expert-only knowledge − what the model already knows.**

A skill's value is its **knowledge delta**. Explaining what a PDF is, or how to write a loop,
compresses knowledge the model already has — that's not teaching, it's spending context. The
context window is shared with the system prompt, the conversation, other skills, and the user's
actual request.

Triage every section as one of:

- **[E] Expert** — the model genuinely doesn't know this. This is the skill.
- **[A] Activation** — it knows, but might not think of it. Keep if brief.
- **[R] Redundant** — it definitely knows. Delete.

Good skill: >70% E, <10% R. Bad skill: <40% E.

## Dimensions (120 points)

| # | Dimension | Max | What earns the points |
|---|---|---|---|
| D1 | **Knowledge delta** | 20 | Every paragraph earns its tokens. Decision trees for non-obvious choices, expert trade-offs, real edge cases. Instant ≤5 for "what is X" sections, standard-library tutorials, or generic "write clean code" advice. |
| D2 | **Mindset + procedures** | 15 | Transfers how to *think* ("before X, ask yourself…") **and** procedures the model wouldn't know (non-obvious ordering, steps easy to miss). Generic open/edit/save sequences score 0-3. |
| D3 | **Anti-patterns** | 15 | A specific NEVER list *with the reason*. "Avoid errors" is worth nothing; "never use purple-on-white gradients — it's the signature of AI-generated design" is expert knowledge. |
| D4 | **Spec compliance, esp. `description`** | 15 | Valid frontmatter; `name` lowercase, ≤64 chars. The description must answer WHAT, WHEN, and carry trigger KEYWORDS. |
| D5 | **Progressive disclosure** | 15 | Layer 1 metadata → Layer 2 body (<500 lines, ideally <300) → Layer 3 `references/` loaded on demand, with explicit triggers *and* "do NOT load" guidance. |
| D6 | **Freedom calibration** | 15 | Constraint matched to fragility: creative work gets principles, fragile operations get exact steps. Ask "if the agent gets this wrong, what breaks?" |
| D7 | **Pattern** | 10 | Recognisably one of: Mindset (~50 lines), Navigation (~30), Philosophy (~150), Process (~200), Tool (~300). |
| D8 | **Usability** | 15 | Decision trees for branching cases, examples that actually run, fallbacks when the main path fails, edge cases. |

**Why D4 outweighs its size:** the agent sees only descriptions when deciding what to load. A
skill with excellent content and a vague description is never activated at all — it is dead
weight. "When to use this" belongs in the description, not the body.

Grades: A ≥108 · B 96-107 · C 84-95 · D 72-83 · F <72.

## Protocol

1. Read the whole SKILL.md; mark each section E / A / R and compute the ratio.
2. Check structure: frontmatter, line count, reference files and their load triggers, which
   pattern it follows.
3. Score each dimension — quote the specific line that justifies the score.
4. Total, grade, and name the top three fixes in impact order.

Report: score and grade, the E:A:R ratio, a one-line verdict, the dimension table, critical
issues, then the three fixes. For anything under 80% of its max, say concretely what to change.

## Common failure patterns

- **The tutorial** — explains basics. Delete them; keep decisions and trade-offs.
- **The dump** — 800 lines, no layering. Route from the body, detail in `references/`.
- **The orphan references** — a `references/` dir nothing ever loads. Add MANDATORY triggers at
  the workflow step that needs them.
- **The checkbox procedure** — mechanical Step 1/2/3. Convert to "before doing X, ask…".
- **The vague warning** — "be careful". Replace with a specific NEVER plus its non-obvious reason.
- **The invisible skill** — great body, weak description; never fires.
- **The wrong location** — "when to use" buried in the body, where it's read too late.
- **The over-engineered** — README, CHANGELOG, CONTRIBUTING around a skill. Ship what the agent needs.

## Never, when judging

- **Never reward polish** — formatting is not knowledge.
- **Never let length impress you** — 43 focused lines beat 500 padded ones.
- **Never forgive redundancy** as "helpful context"; deduct for it.
- **Never skip mentally running the decision trees** — do they actually reach the right branch?
- **Never overlook a missing NEVER list** — that's a real gap, not a stylistic one.

## The meta-question

> Would an expert in this domain read it and say *"yes, that's what took me years to learn"*?

If not, it's compressing what the model already knew.
