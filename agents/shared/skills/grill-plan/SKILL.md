---
name: grill-plan
description: Grill a plan before it gets built — one question at a time, each carrying a recommended answer, until the design is pinned down. Use when the user wants an approach stress-tested, challenged, interrogated, or poked holes in, or says "grill me" about a plan. Reads the codebase for answers instead of asking, sharpens overloaded terms, and flags which decisions are worth recording.
---

# Grill a plan

Interview until the design is understood the same way by both of you, walking one branch at a
time and settling each dependency before the next.

## How to ask

- **One question at a time.** Wait for the answer before asking the next. A batch gets a batch
  reply, and whichever question mattered gets a clause instead of a paragraph.
- **Carry your own recommendation.** Every question arrives with the answer you would pick and
  why, so "yes" is a complete reply and disagreeing is cheap.
- **Read before asking.** If the codebase answers it, go and read it. A question the repo
  already answers spends attention that the open questions need.

## What to push on

- **Overloaded words.** When one term covers two things, propose a canonical name for each:
  "you're saying *account* — Customer or User? Those behave differently."
- **Claims the code contradicts.** If the described behaviour isn't what the code does, name the
  file that disagrees and ask which is right.
- **Boundaries, through scenarios.** Invent the specific case that forces a decision about where
  one concept ends and the next begins.
- **The unstated failure mode.** What happens on the second run, the concurrent run, the
  half-finished run, the run after someone deletes the thing.

## Decisions worth recording

Say a decision is worth recording only when all three hold:

1. **Hard to reverse** — changing course later has a real cost.
2. **Surprising without context** — a future reader will ask why it was done this way.
3. **A genuine trade-off** — there were real alternatives and one was chosen for stated reasons.

Miss any one and it isn't worth recording. When all three hold, name it as a candidate for the
day's `### Decisions` entry, which `/wrap-up` writes.

## Never

- **Never write a spec, plan, or decision file.** The thinking belongs in the conversation, and
  a decision lands in the journal only when the user runs `/wrap-up` — a file written here is
  one nobody asked for and nobody maintains.
- **Never ask what the codebase answers.** It reads as interrogation for its own sake, and each
  wasted question buys less patience for the ones that matter.
- **Never batch questions.** The reply batches too, and the design detail you were actually
  unsure about goes unexamined.
- **Never let a vague term through to keep momentum.** The ambiguity comes back as a bug or a
  rewrite; naming it costs one question now.
- **Never argue the user out of their answer.** Ask, recommend, record the disagreement if it
  matters, and move on — a grilling that becomes advocacy stops producing information.
