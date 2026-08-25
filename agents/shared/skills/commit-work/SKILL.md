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

Per commit, write the message to `<gitdir>/COMMIT_DRAFT`, where `<gitdir>` comes from
`git rev-parse --absolute-git-dir` — not `.git`, which is a *file* in a linked worktree. Use the
**Write tool** for it, not a Bash heredoc or redirect: that path is pre-allowed, a redirect is
not, so a heredoc turns every commit into a permission prompt. An
autocmd reads that draft into the commit buffer and deletes it, so the user commits in neogit
(`c c`) with the message already there and nothing to copy.

Then show:

- the staged paths (`git diff --cached --stat`)
- the drafted message, in the reply too — the draft file is consumed on first open
- the verification result

Wait for the user to commit before staging the next one. Never run `git commit` — the buffer is
theirs to accept, edit, or discard.
