---
name: review
description: Review changes since a fixed point along two axes — Standards (does it follow this repo's documented conventions?) and Spec (does it do what the originating issue asked?). Use when the user wants to review a branch, a PR, work in progress, or asks to "review since X". Reports the axes separately.
---

# Review

Two questions about the same diff, kept apart:

- **Standards** — does the code follow how code is written here?
- **Spec** — does the code do what the issue asked for?

A change can pass one and fail the other. Code that follows every convention can implement the
wrong thing; code that does exactly what was asked can ignore every convention. Merged into one
list, the loud axis hides the quiet one.

## 1. Pin the fixed point, then check it resolves

Whatever the user names — a SHA, a branch, a tag, `main`, `HEAD~5`. Ask if they didn't say.

- `git rev-parse <fixed-point>` — confirm it resolves.
- `git log <fixed-point>..HEAD --oneline` — the commits.
- `git diff <fixed-point>...HEAD` — three dots, so the comparison is against the merge-base.

Stop here on a bad ref or an empty diff. Discovering it later means the reading was wasted.

## 2. Standards

Read what the repo documents, if anything: `CONTRIBUTING.md`, `CODING_STANDARDS.md`, `AGENTS.md`
or `CLAUDE.md`. Those are the standard; quote the rule you're citing.

Where the repo documents nothing, fall back to naming smells. Check the diff for: mysterious
names · duplication · feature envy · data clumps · primitive obsession · repeated switches ·
shotgun surgery · divergent change · speculative generality · message chains · middle man ·
refused bequest.

Three rules bind this axis:

- **A documented repo standard overrides the smell list.** Where the repo endorses something the
  list would flag, the repo wins and the smell is suppressed.
- **Smells are judgement calls, never violations.** Say "possible feature envy", not "violates".
  A breach of a documented standard can be stated hard; a smell cannot.
- **Skip anything tooling already enforces.** A linter, formatter or type-checker finding is not
  a review finding — reporting it wastes the reader's attention on something already automated.

## 3. Spec

Find what asked for this change, in order: an issue referenced in the commit messages or branch
name (`gh issue view <n>`), a path the user gave, or a spec file under `docs/` or `specs/`
matching the branch. If none exists, ask; if there is genuinely none, say "no spec available"
and skip this axis rather than inventing a requirement to review against.

With the spec in hand, report three things — quoting the line of the spec for each:

- **Missing or partial** — the spec asked for it, the diff doesn't deliver it.
- **Scope creep** — the diff does it, nothing asked for it.
- **Implemented wrong** — it's there, but it doesn't do what was asked.

## 4. Report

Two headings, `## Standards` and `## Spec`, findings under each. Per finding: the file and line,
what's wrong, and the rule or spec line it's measured against.

End with one line per axis — how many findings, and the worst one *within that axis*. Don't pick
a single worst across both, and don't merge or rerank the lists. Keeping them apart is the point.

## Never

- **Never merge the two axes** — a page of style findings buries the one requirement that was
  never implemented, which is the more expensive miss.
- **Never report what tooling catches** — it trains the reader to skim the whole review.
- **Never state a smell as a violation** — an overconfident finding costs more trust than a
  missed one, because the next real finding gets discounted too.
- **Never review against a spec you inferred** — if you can't find the issue, say so. A
  requirement you imagined is worse than no Spec axis at all.
- **Never fix what you find** — report it; the change is the user's to make.
