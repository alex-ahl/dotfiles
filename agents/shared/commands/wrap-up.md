---
description: End-of-day journal entry — append what happened to ~/brain/log/<date>/ and update ~/brain/TODO.md
argument-hint: [note]
---

Write today's journal entry to `~/brain/log/<YYYY-MM-DD>/<slug>.md` and refresh `~/brain/TODO.md`.

**Permission-friendly gathering:** run each context command as its OWN Bash call, with no shell
expansion — no `$VARIABLES`, no `~`, no `$(...)`, no redirects, no `;` / `&&` chaining. Expansion
forces an approval prompt; the plain commands below are pre-approved. Write files with the
**Write / Edit tools** (`~/brain/` is pre-authorised in settings), never a Bash heredoc.

Steps:

1. Resolve the target path:
   - Date: today, `YYYY-MM-DD`, from your own context — do not run `date`.
   - Slug: basename of the current working directory (derive it from the `pwd` output below).
     Matches how `/handoff` names its files, so a day's entries line up with its worktrees.
   - Full path: `~/brain/log/<date>/<slug>.md`.
   - Read that path first. **If it exists, append a new `## <HH:MM>` section — never overwrite.**
     A day file is a journal, and the other account's pane may already have written to it.

2. Gather — each as a SEPARATE, plain Bash call:
   - `pwd`
   - `git rev-parse --abbrev-ref HEAD`
   - `git log --since=midnight --oneline`   (today's commits here)
   - `git status --short`                   (what's still in flight)

   If `$ARGUMENTS` is non-empty, treat it as the headline note for this entry.

   Other repos touched today: ask, don't guess. If the user names any, gather the same way for
   each. Their PR state via `gh` is useful but **will prompt** — only reach for it if asked.

3. Ask two questions, and only two:
   - **Stuck?** — anything blocked, or a dead end worth remembering.
   - **Next?** — what picks up tomorrow.

   Everything else comes from the commits, the diff, and this conversation. Don't interview the
   user for what the repo already knows.

4. Write the entry (Write for a new file, Edit to append):

   ```markdown
   # <slug> — <YYYY-MM-DD>

   ## <HH:MM> <branch>

   ### Done
   - <outcomes, not commit subjects>

   ### Decisions
   - <choice + the reason — this is the part nothing else records>

   ### Stuck
   - <blockers, dead ends, "tried X, failed because Y">

   ### Next
   - <what picks up tomorrow>
   ```

   Omit any section with nothing real in it. Decisions and Stuck matter most: commits record what
   worked, and nothing else records why, or what was abandoned.

5. Refresh `~/brain/TODO.md` — read it, then Edit. One `## <repo>` heading per repo, `- [ ]` items
   under it. Tick off what got done today, add what came out of **Next**, and leave the rest alone.
   Create the file if it isn't there yet.

6. Print the entry path and one line on what was captured.

Rules:
- No secrets, tokens, or credentials in the file — `<REDACTED>` instead.
- Keep an entry under ~30 lines. It's a journal, not a report; the diff is still in git.
- Never overwrite an existing day file — append.
- `~/brain/` lives outside every repo, so entries survive `wt-prune` removing the worktree and are
  shared by both accounts.
