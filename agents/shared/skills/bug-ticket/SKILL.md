---
name: bug-ticket
description: Draft a bug ticket and file it as a GitHub issue. Use when the user asks to write, draft, or file a bug, bug ticket, bug report, or GitHub issue, or describes a bug and wants it in ticket form. Produces Background, Steps to reproduce, Expected, Actual in plain language — no fix suggestions, no diagnosis, no jargon.
---

# Bug ticket

Four sections, plain language, written for a teammate who picks it up cold next sprint and runs
the steps without opening the repo.

**Draft first, file only when asked.** Show the ticket in the conversation. An issue is public
and outward-facing — `gh issue create` runs only when the user explicitly says to file it.

## 1. Which repo

Don't assume the current worktree. Ask, or confirm what you resolved: `gh repo view --json
nameWithOwner` in the repo the bug is *in*, which is often not the one you're standing in.
`repo-pointer` resolves a short name to a path if the user names a different project.

If the repo uses labels, check `gh label list` and propose one — don't invent labels.

## 2. Shape

Four sections, in this order, nothing else:

1. **Background** — one short paragraph. What surface is affected and the operational situation
   that produces the bug. No code references, no class or method names, no file paths. Pretend
   the reader hasn't seen the codebase. Name the environment and roughly when it started only
   when either is load-bearing.
2. **Steps to reproduce** — numbered list. Concrete, ordered actions that reliably produce the
   bug. Each step is one observable action (publish, stop, read, restart, read again). Mention
   timing only when it's load-bearing for a race. Describe what an operator would actually do,
   not internal mechanisms.
3. **Expected** — one or two sentences on what the system should do.
4. **Actual** — facts only. The state of the system after the reproduction completes. No
   evaluation, no consequences, no diagnosis, no fix.

## 3. Rules

- **No fix suggestions.** Not in any section. The ticket describes the bug, not the solution.
  A suggested fix belongs in a comment or a PR description, never in the ticket body.
- **No evaluation in Actual.** "X happens" is fine. "X happens, which means Y is broken" or
  "the only way to recover is Z" is not. State the post-condition and let whoever picks it up
  form their own theory — a diagnosis in the ticket anchors the next person to your first guess.
- **No code-level vocabulary.** No class names, method names, file paths, table names, ORM or
  framework terms, line numbers. Use the operator-visible equivalent: "the domain", "the source
  layer", "the consumer", "the read endpoint".
- **No extra framing.** No Summary, Root cause, Impact, Related, Notes, or Suggested fix
  sections. The four are enough.
- **No emoji, no checkboxes, no ornament** beyond the headings and the numbered list.
- **Short.** Background ≤ 4 sentences. Each step ≤ 1 sentence. Expected ≤ 2. Actual ≤ 2. A
  section straining the limit means the wording is wrong, not the limit.

## 4. Template

```
Title: <one short clause: the surface and the failure>

## Background
<where this happens and the operational situation that produces it>

## Steps to reproduce
1. <action>
2. <action>

## Expected
<what the system should do>

## Actual
<what the system does — facts only>
```

## 5. Filing

Only on an explicit ask. Write the body to a file first, then:

```
gh issue create --repo <owner/name> --title "<title>" --body-file <path> [--label <label>]
```

Report the issue URL. If the user wants it assigned or added to a project, they say so — don't
volunteer either.

## Never

- **Never file without being asked** — an issue notifies people and is public. Drafting is
  reversible; filing is not.
- **Never put a diagnosis or a fix in the ticket** — you're usually guessing, and a wrong guess
  in the body costs the next person more time than an empty body would.
- **Never use the vocabulary of the code** — the reader may be on another team, and a ticket
  they can't parse gets triaged into silence.
- **Never pad a section to look thorough** — four short sections that reproduce the bug beat a
  page that doesn't.
