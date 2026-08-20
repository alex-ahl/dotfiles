---
description: List and optionally delete handoff files in ~/handoffs/. Supports filtering by age or name.
argument-hint: [--older-than Nd | --all | <name>]
---

Manage the handoff folder.

Steps:

1. Always start by listing: `ls -lt ~/handoffs/*.md 2>/dev/null`. Show filename + age + size. If no files, say so and stop.

2. Interpret `$ARGUMENTS`:
   - **empty** → just listed; ask the user what to delete (or none).
   - **`--all`** → list everything, then ask for explicit confirmation before deleting all `.md` files in `~/handoffs/`. Never delete without confirmation.
   - **`--older-than Nd`** (e.g. `--older-than 30d`) → use `find ~/handoffs -maxdepth 1 -name "*.md" -mtime +N` to list candidates, confirm, then delete.
   - **`<name>`** → delete a single file `~/handoffs/<name>.md`. Confirm first. If missing, suggest nearest match.

3. Always require explicit "yes" before any `rm`. Never use `rm -rf`. Delete files one-by-one or via a confirmed `find ... -delete` after listing.

4. After deletion: list remaining files and print the count freed.

Rules:
- Never touch `~/handoffs/commands/` — that folder holds the slash command sources themselves. Only delete `*.md` files directly in `~/handoffs/`, not subdirectories.
- Refuse to operate if `~/handoffs/` does not exist.
- If any file looks active (modified in last 1 hour), warn before deletion.
