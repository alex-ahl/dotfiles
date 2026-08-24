---
name: lesson-learned
description: Extract software-engineering lessons from recent code changes. Use when the user asks what we learned from a change, branch, or set of commits — "lessons learned", "retro on this branch", "what should we do differently", "review what this taught us" — or when wrapping up a piece of work.
---

# Lesson learned

Read what actually changed and name what it teaches. Reflective, not prescriptive — the point is
to notice a pattern worth carrying forward, not to grade the work.

## 1. Scope it

Ask what to look at if it isn't obvious: this branch against its base, the last N commits, or one
specific change. Default to the current branch since its merge-base.

## 2. Gather the real changes

Run in the current worktree (cwd persists; no `cd` prefix):

- `git rev-parse --abbrev-ref origin/HEAD` for the base branch.
- `git log --oneline <base>..HEAD` — the sequence, and what the messages claim.
- `git diff <base>...HEAD` — three dots, since the merge-base.
- `git diff --stat <base>...HEAD` first when the change is large, then read what matters.

Read the commit messages as evidence, not noise: a string of "fix", "fix again", "actually fix"
is itself the lesson, and reverts mark where an assumption broke.

## 3. Analyse

Look for what the diff reveals about how the work went, not just what it does:

- Where did the design have to change mid-stream, and what would have surfaced that earlier?
- What was harder to change than it should have been — coupling, missing seam, hidden state?
- Which bug class appeared, and is it the kind a test or type would have caught for free?
- What got repeated, and what does the repetition suggest is missing?
- Where did a shortcut hold up fine? Restraint is a lesson too.

## 4. Present at most three

Per lesson: what happened, grounded in a `file.ts:42` reference or a specific commit; the
principle it points at; and what to do differently, concretely enough to act on next time.

Three is the ceiling. Ten lessons is a list nobody carries into the next branch.

Keep it in the conversation. Only write a file if the user asks.

## Never

- **Never list every principle the diff vaguely touches** — SOLID-bingo is filler; one real
  observation beats six textbook ones.
- **Never write a lesson you can't anchor to a line of the diff** — unanchored advice is horoscope.
- **Never ignore the commit messages** — the struggle is recorded there more honestly than in the
  final state of the code.
- **Never turn it into a code review** — this is about what the work taught, not what to fix now.
  Real defects still worth flagging go to `/code-review`, not here.
