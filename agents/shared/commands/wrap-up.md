---
description: End-of-day journal entry — append what happened to the work or personal brain and update its TODO
argument-hint: [note]
---

Write today's journal entry to `~/brain/<brain>/log/<YYYY-MM-DD>/<slug>.md` and refresh
`~/brain/<brain>/TODO.md`.

**Permission-friendly gathering:** run each context command as its OWN Bash call, with no shell
expansion — no `$VARIABLES`, no `~`, no `$(...)`, no redirects, no `;` / `&&` chaining. Expansion
forces an approval prompt; the plain commands below are pre-approved. Write files with the
**Write / Edit tools** (`~/brain/` is pre-authorised in settings), never a Bash heredoc.

Steps:

1. Resolve the target path:
   - **Which brain — ask, don't infer.** `work` for the employer's services, repos and tickets;
     `personal` for your own projects, code very much included. The split is whose work it is,
     not whether it's code, and nothing in the repo reliably says which. `$ARGUMENTS` may carry
     it (`/wrap-up work`), in which case don't ask.
   - Date: today, `YYYY-MM-DD`, from your own context — do not run `date`.
   - Slug: basename of the current working directory (derive it from the `pwd` output below).
     Matches how `/handoff` names its files, so a day's entries line up with its worktrees.
   - Full path: `~/brain/<brain>/log/<date>/<slug>.md`.
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

3. Two questions, and only two:
   - **Blockers?** — anything blocked, plus dead ends worth remembering ("tried X, failed
     because Y"). Not only what stops you — also what cost you an hour and might again.
   - **Next?** — what picks up tomorrow.

   **Answer them yourself first, then ask for a correction, not an answer.** State your read of
   both from the conversation and the commits, so "no / ok" is a complete reply. A one-word
   confirmation is the expected case; only a genuinely blank day needs the user to type.

   `$ARGUMENTS` may carry the answers directly (`/wrap-up no / code-review tomorrow`) — take them
   and skip the asking entirely.

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

   ### Blockers
   - <what's blocked, and dead ends: "tried X, failed because Y">

   ### Next
   - <what picks up tomorrow>
   ```

   Omit any section with nothing real in it. Decisions and Blockers matter most: commits record
   what worked, and nothing else records why, or what was abandoned.

5. Refresh that brain's `TODO.md` — read it, then Edit. One `## <repo>` heading per repo, `- [ ]` items
   under it. Tick off what got done today, add what came out of **Next**, and leave the rest alone.
   Create the file if it isn't there yet.

   **Record intentions, not state.** If a command can answer it, don't write it down: no commit
   counts, no "4 commits ahead", no "as of <date>" qualifiers, no branch or PR status. They're
   wrong the moment anything changes, and then they get read as current. "Push master" is a task;
   "Push master (4 commits ahead as of Monday)" is a task plus a lie waiting to happen.

6. Print the entry path and one line on what was captured.

Rules:
- No secrets, tokens, or credentials in the file — `<REDACTED>` instead.
- Keep an entry under ~30 lines. It's a journal, not a report; the diff is still in git.
- Never overwrite an existing day file — append.
- `~/brain/` lives outside every repo, so entries survive `wt-prune` removing the worktree and are
  shared by both accounts.
