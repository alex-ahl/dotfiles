---
name: commit-work
description: Use when committing work — reviewing and staging the intended changes, splitting them into logical commits, and writing Conventional Commits messages. Stages and drafts; the user runs the commit.
---

# Commit work

Commits that are easy to review and safe to ship: only the intended changes are in, each
commit is one logical scope, and the message says *what* changed and *why*.

**Git is the user's to drive.** This skill inspects, stages, and drafts messages. It never
runs `git commit`, `git push`, or creates branches — hand the message back and let the user
commit.

**Scope: this session, this repo.** Stage only changes made in this session, in the current
worktree. Anything already modified when the session started belongs to whoever made it —
list it so the user knows it's there, and leave it alone. A submodule is a separate repo: a
dirty one gets reported, never staged or committed on the user's behalf.

## 1. Inspect before staging

Run each as its own command in the current worktree (cwd persists; no `cd` prefix):

- `git status --short`
- `git diff` — unstaged changes.
- `git diff --cached` — don't assume the index is empty; something may already be staged.
- Large change: `git diff --stat` first, then read the parts that matter.

## 2. Decide commit boundaries

Split by: feature vs refactor · logic vs formatting · tests vs production code · dependency
bumps vs behaviour changes · unrelated subsystems.

Default to several small commits when the changes are unrelated, one commit when they're one
idea. If a commit needs more than a sentence to describe, it's too big — split it.

## 3. Stage only what belongs in this commit

- Never `git add .` or `git add -A`.
- Per path: `git add <path>`. Unstage: `git restore --staged <path>`.
- Mixed hunks inside one file: `git add -p` is interactive and unavailable to an agent. Say
  which hunks belong in this commit and hand the split to the user — neogit stages hunks with
  `s` in its status buffer. Only fall back to a written patch (`git diff <path>` → cut it down
  → `git apply --cached`) when the user would rather not do it by hand.

## 4. Review what is actually staged

`git diff --cached`, checking for:

- secrets, tokens, `.env` values, credentials
- debug logging, commented-out experiments, stray `TODO`s
- unrelated formatting churn
- anything belonging to a different commit's scope

## 5. Describe it in one or two sentences

"What changed" + "why". If that can't be said cleanly, the boundaries are wrong — back to
step 2.

## 6. Write the message

Conventional Commits, unless the repo's own history clearly uses something else — check
`git log --oneline -20` and match it.

```
type(scope): imperative summary

What changed, and why it matters.

BREAKING CHANGE: <consequence>   # only when it is one
```

- Types: `feat` `fix` `refactor` `chore` `docs` `test` `perf` `build` `ci`.
- Summary: imperative, specific, no trailing period, ≤72 chars. "Fix token expiry off-by-one"
  beats "Bug fix".
- Body: intent and consequence, not an implementation diary. Omit it when the summary really
  is the whole story.
- `references/commit-message-template.md` has the bare template.

## 7. Verify

Run the repo's fastest meaningful check against the staged state (unit tests, lint, or
build). Report the real result — if it fails, say so with the output instead of committing
around it.

## 8. Hand off

Name the whole boundary plan up front ("two commits: skills, then brain") so the user knows how
many rounds are coming. The index holds one state, so commits are prepared strictly one at a
time — stage commit 2 only after commit 1 has landed.

Per commit, write the message to `~/brain/COMMIT_DRAFT`. An editor autocmd reads it into the
commit buffer and deletes it, so the user commits in neogit (`c c`) with the message already
there and nothing to copy. Deliberately outside the repo: agents are commonly barred from
writing inside `.git`, and one shared file is enough because commits are prepared one at a
time and the draft is consumed on first open.

Write the file directly rather than through a shell heredoc or redirect — a direct file write
is one reviewable operation, while a redirect is an arbitrary shell command and far more likely
to be gated.

Then show:

- the staged paths (`git diff --cached --stat`)
- the drafted message, in the reply too — the draft file is consumed on first open
- the verification result

Wait for the user to commit before staging the next one.

## Never

- **Never `git add .` or `git add -A`** — they sweep in whatever else is dirty, which is
  exactly the work you didn't make and can't describe.
- **Never stage a change you didn't make this session** — you can't say what it's for, so the
  message would be a guess. Report it and let the user decide.
- **Never cross a repo boundary** — not into a submodule, not into another checkout. Each repo
  gets its own session, its own staging, its own commit.
- **Never commit a file whose staged diff you haven't read** — a secret is unreviewable once
  it's in history, and rewriting shared history is worse than the leak.
- **Never run `git commit` or `git push`** — the buffer is the user's to accept, edit, or
  discard, and the commit is theirs to make.
