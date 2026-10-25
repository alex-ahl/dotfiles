---
name: where
description: Summarise where the current project stands and what comes next — done, uncommitted, waiting on the user, next steps. Use when the user asks "what next", "whats next", "next steps", "where we stand", "where were we", or "recap" — often right after finishing something ("commits done, whats next") or picking work back up after a break.
---

# Where we stand

A short, current answer to "where are we and what's next", built from what is true now —
not from memory of the conversation, which goes stale the moment the user commits.

## 1. Gather (read-only, in the current repo)

- `git status --short --branch` — uncommitted work, and ahead/behind its upstream.
- `git log --oneline -10` — what landed recently.
- The project's own state document, the first that exists: `docs/HANDOFF.md`,
  `HANDOFF.md`, `TODO.md`; else whatever `AGENTS.md` or `CLAUDE.md` names as current state.
  Read its latest dated section, its milestones, and its open items.
- This conversation: decisions or questions put to the user and not yet answered, and
  work done here that git shows as uncommitted.

If there is no state document, say so in one line and build the answer from git and the
conversation.

## 2. Answer in this shape

One line first: where things are (milestone, step, or the last thing finished).

- **Done recently** — from the git log, newest first; at most five.
- **Uncommitted** — only what `git status` shows right now. Omit the section when clean.
- **Waiting on you** — decisions, approvals, or actions only the user can take.
- **Next** — one to three steps, ranked; the first concrete enough to start now.

## Rules

- Never change files, stage, or commit.
- Say nothing about git state you didn't just read.
- Cite files as `path:line` where it helps; don't retell history the user already knows.
