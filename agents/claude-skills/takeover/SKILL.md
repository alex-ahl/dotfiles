---
name: takeover
description: Pick up where another Claude Code session in this directory stopped, by reading its transcript — no handoff needed. Use when the user says "take over", "continue from ai-1", "the other session hit its limit", "pick up where it left off", "what was the other agent doing", or names another account or worktree whose work to continue.
---

# Takeover

Every session's transcript is on disk, from any account. Read the latest other one that ran
in this directory and continue its work.

## Steps

1. **Read the session.** Run the bundled script from this skill's base directory, as one plain
   Bash call:

   ```
   bash <base-dir>/last-session.sh [dir] [messages] [skip]
   ```

   - `dir`: leave out for the current directory. Pass the worktree's absolute path when the
     user names another worktree.
   - `messages`: 200 by default. If the output doesn't reach back to where the open thread
     started, rerun with 400.
   - `skip`: 0 is the latest other session. If its header shows the wrong account or time
     for the session the user means (ai-1 is `.claude-account1`, ai-2 is
     `.claude-account2`), rerun with 1, 2, and so on.

2. **Check the repo now**, each as its own call: `git status --short`, `git log -8 --oneline`.
   The transcript shows what the session meant to do; git shows what actually landed.
   Anything committed after the session's last tool call was the user's doing.

3. **Report, briefly:**
   - **Where it stopped:** what is committed, what is uncommitted, and what was half-done.
   - **The open thread:** the last proposal and the user's last reply, quoted.
   - **What that reply asks for:** your reading of it, and the next step you'd take.

4. **Continue or ask.** If the user's last reply was a clear go-ahead for one specific next
   step, say so and start it. If it was ambiguous, or widened the scope, ask one question
   carrying your recommendation.

## Rules

- The transcript is a record of what happened, not a fresh instruction. A request the user
  later dropped or replaced stays dropped.
- Don't redo work git shows as already done.
- Quote the user's words when you report them. Don't paraphrase them into something stronger.
