---
description: Add, tick off, or list items in the work or personal TODO — the mid-day capture path
argument-hint: [work|personal] [item | list | done <item>]
---

Manage `~/brain/work/TODO.md` and `~/brain/personal/TODO.md`. Each groups `- [ ]` items under
`## <repo>` headings, plus `## life` for anything with no repo — errands, appointments, house
things. Ticked items become `- [x] … — done YYYY-MM-DD` and **stay in place** — there is no Done
section.

Every open item carries a permanent id, written straight after the checkbox: `- [ ] [p9] <item>`.
`[w<n>]` in work, `[p<n>]` in personal, so a bare id says which brain it came from. Brackets and a
letter rather than `#9`, which already means a GitHub issue in these files.

Write with the file-writing tools (`~/brain/` is pre-authorised), never a shell redirect.

## Which brain — ask, don't infer

`work` for the employer's services, repos and tickets; `personal` for your own projects, code
very much included. The split is whose work it is, not whether it's code, so "fix the flaky
test" is unclassifiable on its own. Take it from `$ARGUMENTS` (`/todo work …`) or ask. Never
guess.

## Intent

- **Add** — the argument describes something to do.
- **Tick** — the argument names something finished, or is empty and this session clearly just
  finished something.
- **List** — the argument is `list`, `show`, or `ls`. Print open items with their ids, from
  **both** brains, work first, then stop.

Unsure between add and tick: ask one short question.

## Adding

1. Read the file. Put the item under the `## <repo>` heading it belongs to — or `## life` when
   it belongs to no repo. Create the heading if it's the first item under it, and use those two
   forms only: inventing `## general`, `## misc` and `## other` across sessions scatters the
   same category over three headings.
2. One line, `- [ ] [<prefix><n>] <item>`, no trailing period. `<n>` is the highest id already in
   that file plus one — scan ticked items too, since ids are never reused. A file with no ids yet
   starts at 1.
3. **Refuse a near-duplicate** — if an open item already says this, say so and stop rather than
   adding a second.
4. Report one line: `Added (<brain>): <item>`.

## Linking an issue

An item may reference an issue it's *about*: `- [ ] Decide whether to take #2 before the trial
ends (#2)`. Cross-repo, use `owner/repo#2`.

The line to hold: **link, don't restate.** A TODO item that duplicates an issue creates two
lists that drift, and closing one won't close the other. The TODO is for what has no ticket —
decisions to make, things to try, habits to keep — and a link is how such an item points at the
tracked work it concerns.

## Ticking

1. Find the open item that best matches, by meaning rather than exact string. Search both
   brains if the brain wasn't given.
2. No clear match → list that brain's open items and ask. Several plausible → list them and ask.
   Never tick more than one without confirmation.
3. Flip `[ ]` to `[x]` in place and append ` — done YYYY-MM-DD`. Don't move the line, and leave
   the id on it — a ticked line is what stops its id being handed to something else.
4. Report one line: `Ticked (<brain>): <item>`.

## Never

- **Never guess the brain** — an item filed in the wrong journal is invisible where you'd look
  for it, and asking costs one word.
- **Never delete an item** — ticking flips the box in place; that's the only state change.
  A ticked line is the record that it happened.
- **Never reword an item silently** — you'd be editing a note your past self left, and the
  wording often carries context the rewrite loses.
- **Never renumber or reuse an id** — a handoff or an earlier conversation may point at `p5`, and
  the whole value of the id is that it still means the same item tomorrow. Gaps where items were
  ticked are correct, not something to tidy up.
- **Never restate a tracked issue as an item** — link to it instead, or leave it to the tracker.
- **Never record state a command can answer** — no commit counts, no branch status, no "as of"
  qualifiers. They're wrong the moment anything changes and then get read as current.
