---
name: pull-request
description: Use when writing, drafting, or improving a GitHub pull request — its title, its description, or both. For a reviewer who lacks the author's context.
---

# Pull request

Write the PR so a reviewer who doesn't share your context understands *what* changed,
*why*, and *how to check it*. A clear title plus a description built from the sections
below.

## Gather context first

Before writing, read the actual change — don't infer it from the conversation alone.
Run each as its own command in the current worktree (cwd persists; no `cd` prefix):

- Base branch: `git rev-parse --abbrev-ref origin/HEAD` (falls back to `main`/`master`).
- Commits on this branch: `git log --oneline <base>..HEAD`.
- The diff: `git diff <base>...HEAD` (three dots — since the merge-base).
- Linked issue, if any: infer the number from the branch name or commits, then
  `gh issue view <n>` for its intent. The issue tells you the *why* and the test surface.

## Title

Concise and informative — conveys the nature of the change at a glance.

- State the change, not the category. "Fix overflow in profile modal" beats "Bug fix".
- Lead with the effect (fix / add / remove / refactor), name the surface, name the thing.
- No ticket dumps or vague nouns ("updates", "changes") as the whole title.

## Description

Include these sections; omit one only when it genuinely doesn't apply (say so rather than
leaving an empty heading).

1. **Summary** — What changed and, above all, **why**. Lead with the problem and why it
   matters. Reviewers read this first and rely on it most.
2. **Related issues / PRs** — Link what this closes and any dependent PRs. Use closing
   keywords (`Closes #123`) so the merge auto-closes the issue.
3. **Visuals** — For any UI change, before/after screenshots or a short gif. Skip when
   there's no visual surface.
4. **Steps to test** — Exact, ordered steps a reviewer follows to verify: commands to run,
   pages to visit, data to set up. No guessing.
5. **Additional notes** — Known issues, deliberate trade-offs, areas you want scrutinised,
   follow-ups deferred to later PRs.

## Guiding principles

- **Context is the point.** Explain the *why* — the diff already shows the *what*.
- **Write for an outsider.** Assume the reviewer doesn't know this feature's background.
- **Bullets over prose** for lists of changes, steps, and notes — easier to scan.

## Template

```
Title: <effect + surface + specific thing>

## Summary
<what changed and why — lead with the problem and why it matters>

## Related issues / PRs
Closes #<id>
Related: #<id>

## Visuals
<before/after screenshots or gif — for UI changes>

## Steps to test
1. <command / page / action>
2. <command / page / action>

## Additional notes
- <known issues, trade-offs, areas of concern, follow-ups>
```

## Handing off

Git is the user's to drive. Draft the title and body and show them in the chat; **do not**
push, branch, or open the PR on your own. Only run `gh pr create` (default `--draft`) when
the user explicitly asks, passing the drafted title and body via `--title` / `--body-file`.
