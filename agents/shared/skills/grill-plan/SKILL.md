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
- **Read before asking.** If the codebase answers it, go and read it — a question the repo
  already answers spends attention the open ones need.

## What to push on

- **Overloaded words.** When one term covers two things, propose a canonical name for each:
  "you're saying *account* — Customer or User? Those behave differently." A term left vague
  comes back as a bug or a rewrite.
- **The unstated failure mode.** The second run, the concurrent run, the half-finished run, the
  run after someone deletes the thing.

## Decisions worth recording

Say a decision is worth recording only when all three hold:

1. **Hard to reverse** — changing course later has a real cost.
2. **Surprising without context** — a future reader will ask why it was done this way.
3. **A genuine trade-off** — there were real alternatives and one was chosen for stated reasons.

Miss any one and it isn't worth recording. When all three hold, name it as a candidate for the
day's `### Decisions` entry, which `/wrap-up` writes — don't write it anywhere yourself.

## Never

- **Never argue the user out of their answer.** Ask, recommend, note the disagreement if it
  matters, and move on — a grilling that turns into advocacy stops producing information.
