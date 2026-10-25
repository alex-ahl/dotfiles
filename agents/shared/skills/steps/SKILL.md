---
name: steps
description: Re-show the steps the user is in the middle of — every step of the procedure you gave them, which are done, which is current, and what remains — after questions and answers have pushed the steps out of view. Use when the user says "steps", "what were the steps", "which step was I on", "show the steps again", or asks to continue a procedure.
---

# Steps

The user was given a procedure to run — commands, edits, installs — then asked about one
step, and the answers buried the rest. Bring the whole procedure back into view.

## 1. Find the procedure

- The most recent set of steps given to the user in this conversation: numbered or listed
  actions *they* must take (not work you did yourself).
- Any `~/handoffs/*.md` written in this session that holds steps for the user.
- If several procedures are open, take the most recent one in full and list the others
  in one line each.

## 2. Work out where they are

For each step, decide: done, current, or remaining.

- **Done** only with evidence: the user said so, their output showed it, or it can be
  checked now (the file exists, the rule is in the deployed file, the tool is installed).
  Check where a cheap read-only check exists.
- **Current** — the first step not done.
- When unsure, say so on that step rather than guessing.

## 3. Answer in this shape

One line: "Step N of M: <what it does>."

Then every step, numbered as originally given:

- Done steps: one line each, marked ✓.
- The current step: its full text, with commands in copyable code blocks, and any
  question the user asked about it answered in one line.
- Remaining steps: full text, commands in copyable code blocks.

## Rules

- Keep the original numbering and wording; don't add, drop, or reorder steps.
- Don't re-explain done steps.
- Never run the user's steps for them, and never change files.
