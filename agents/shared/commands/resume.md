---
description: Load a handoff file from ~/handoffs/ and pick up where the previous session left off
argument-hint: [name]
---

Resume from a handoff at `~/handoffs/$ARGUMENTS.md`.

Steps:

1. If `$ARGUMENTS` is empty:
   - `ls -lt ~/handoffs/*.md 2>/dev/null` to list available handoffs newest-first.
   - Ask the user which one to load (or hint that they can pass the slug directly).
   - Stop here until the user picks.

2. If `$ARGUMENTS` is given:
   - Read `~/handoffs/$ARGUMENTS.md`.
   - If missing, list nearest matches via `ls ~/handoffs/` and ask.

3. After reading:
   - Print a 3–5 line summary: Goal, Branch, Last decision, Next action.
   - Resolve the allowed-repo set: the `Repo:` path plus every entry under `Related repos:` (if present). Treat all of them as valid working directories for this task.
   - Do NOT `cd` automatically. Compare `pwd` against the allowed-repo set:
     - **cwd is the primary `Repo:`** → confirm with `git status --short` and `git rev-parse --abbrev-ref HEAD`, offer to start the next action.
     - **cwd is in `Related repos:`** → no warning. Print one line noting which related repo you're in and which steps of the plan map to it (infer from the handoff body if possible). Offer to proceed.
     - **cwd matches none** → tell the user:
       ```
       This handoff covers: <primary-repo> + <related-repos>.
       You are in <pwd>.
       cd into one of the listed repos to continue, or run `claude --resume <session-id>` from <primary-repo> for full transcript continuity.
       ```

Rules:
- Do not modify code or run destructive commands as part of resuming. Resume = read state and confirm orientation.
- If the handoff references a `Source session` id, mention the user can also try `claude --resume <id>` from the recorded repo path for full transcript continuity.
