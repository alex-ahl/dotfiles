---
description: Save current conversation state to ~/handoffs/<name>.md for cross-session/cross-account resume
argument-hint: [name]
---

Create a handoff file at `~/handoffs/$ARGUMENTS.md`. If `$ARGUMENTS` is empty, default the name to the current repo's directory basename.

**Permission-friendly gathering (important):** run each context command as its OWN Bash call, and never use shell expansion — no `$VARIABLES`, no `~`, no `$(...)`, no redirects (`>` / `2>`), and don't chain with `;` / `&&`. A command containing expansion forces an approval prompt; the plain commands below are pre-approved. Use the **Write tool** for the file itself (the `~/handoffs/` directory is pre-authorised in settings), not a Bash heredoc.

Steps:

1. Resolve target path:
   - If `$ARGUMENTS` is non-empty, use it as the filename slug (kebab-case). Else use the basename of the current working directory (derive it from the `pwd` output below — do not run `basename ~/...`).
   - Full path: `~/handoffs/<slug>.md`.
   - To check whether it already exists, use the **Read tool** on that path (not a Bash `test`/`ls`). If it exists, ask the user: overwrite, append a timestamp suffix, or abort. (When invoked by automation the slug is already unique, so this won't trigger.)

2. Gather context — run each as a SEPARATE, plain Bash call (no expansion, per the note above):
   - `pwd`
   - `git rev-parse --abbrev-ref HEAD`   (current branch)
   - `git status --short`                (uncommitted state — never use `-uall`)
   - `git log -5 --oneline`              (recent commits)

   Session id (for the `Source session:` line): take it from your own runtime context if you have it. Do NOT run `echo $CLAUDE_CODE_SESSION_ID` — that expansion forces a prompt. If you don't have the id, omit the `Source session:` line entirely.

   Also identify **related repos**: any other repos discussed in the conversation that hold part of this task (e.g. backend + frontend, k8s manifests + service code). Record their absolute paths. Single-repo tasks: leave the list empty.

3. Write the file (with the Write tool) with this structure:

   ```markdown
   # Handoff — <slug>

   Source session: <session-id>   <!-- omit this whole line if the id is unavailable -->
   Repo: <pwd> (branch `<branch>`)
   Related repos:
   - <absolute-path>  # one per line; omit the whole field if none
   Date: <today YYYY-MM-DD>

   ## Goal
   <one-paragraph: what we are trying to accomplish in this thread>

   ## Decisions made
   <bulleted: each major decision + one-line reason>

   ## Current state
   <what is wired up vs. what is still broken; reference file paths with line numbers>

   ## Open questions
   <bullets, only real unknowns>

   ## Uncommitted changes
   ```
   <git status --short output>
   ```

   ## Recent commits
   ```
   <git log -5 --oneline output>
   ```

   ## Next actions
   1. <ordered list of concrete next steps>
   ```

4. Synthesise the Goal / Decisions / Current state / Open questions / Next actions sections from this conversation. Do not hallucinate — only include items actually discussed. If a section has no real content, omit it rather than padding.

5. Print the final path and a one-line summary of what was captured. Remind the user they can resume with `/resume <slug>` from any folder, any account.

Rules:
- Do not include secrets, tokens, or full credentials in the file even if they appeared in the conversation. Replace with `<REDACTED>`.
- Keep the file under ~250 lines. If the thread is long, summarise rather than transcribe.
- File lives outside any repo so it survives `git clean` / folder moves / account switches.
- Gather with separate, expansion-free Bash commands and write via the Write tool, so the handoff runs without permission prompts.
