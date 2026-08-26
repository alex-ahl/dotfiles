---
name: daily-meeting-update
description: Interactive daily standup / meeting update generator. Use when the user says "daily", "standup", "scrum update", "status update", "what did I do yesterday", "morning update", "prepare for the meeting", or "team sync". Pulls activity from git and GitHub with consent, runs a four-question interview, and produces a short formatted update.
---

# Daily meeting update

Generate the standup update through an **interview**. Git and GitHub supply memory triggers;
they don't write the update. Ask before touching anything.

## 1. Detect and offer, before asking anything else

**Read `~/brain/work/log/<yesterday>/` first, if it exists** — the work brain only; the personal
one isn't standup material. That's the journal, and it answers
question 1 directly — including the decisions and dead ends that never reached a commit. With a
log entry in hand, "what did you do yesterday?" becomes "anything to add?".

Then check quietly (suppress errors, don't narrate): inside a git repo · `gh auth status` succeeds ·
`~/handoffs/*.md` modified recently · other wsg sessions (`tmux -L wsg list-sessions`), which in
this worktree setup is the best index of what was worked on.

Then ask — once, not per source: *"Want me to pull yesterday's activity from git/GitHub, or
will you tell me?"* If yes, ask **which repos** — worktrees mean several checkouts of the same
project, and there are usually 2-5 in flight.

Pull only what was approved:

- Commits: `git log --author <user> --since yesterday --oneline` per approved repo.
- PRs opened/merged: `gh pr list --author @me --state all --limit 20 --json number,title,state,updatedAt`
  — current repo only; filter by `updatedAt` yourself rather than passing a search string.
- Reviews given: `gh search prs --reviewed-by @me --updated ">=<date>"` — searches across repos,
  and returns nothing (exit 0) when there are none, so don't read silence as an error.
- Handoffs written yesterday (`~/handoffs/`) — they capture research and decisions that never
  reached a commit.

Never pull from a repo the user didn't name, even if it's sitting right there.

## 2. Interview, with the data as context

Show what you found first, then ask. Pulled data makes the questions sharper — "I see PR #125
merged; what else?" recovers far more than "what did you do yesterday?".

1. **Yesterday** — what they worked on. Probe vague answers once.
2. **Today** — what they're picking up.
3. **Blockers** — anything in the way.
4. **Topics for the meeting** — anything to raise at the end.

Ask all four. The fourth is the one tools can never reconstruct and is often the most valuable
thing said in the meeting.

## 3. Produce the update

```markdown
# Daily update — <date>

## Yesterday
- <outcomes, not commit messages>

## Today
- <what they're picking up>

## Blockers
- <blockers, or "None">

## PRs & reviews
- Opened / Merged / Reviewed: #<n> — <title>

## Topics for discussion
- <topics, or "None">
```

Print it in the conversation. Only write a file if the user asks.

## Never

- **Never pull before asking** — repos can be private, sensitive, or none of the meeting's business.
- **Never skip the interview because the tools returned plenty** — commits capture what happened,
  not why, and miss research, meetings, and dead ends entirely.
- **Never paste raw commit messages** — "fix", "wip" tell the team nothing. Summarise into outcomes.
- **Never exceed ~15 bullets** — a standup update should read in under two minutes.
- **Never cite a PR or ticket number without its title** — "#123" alone is noise.
