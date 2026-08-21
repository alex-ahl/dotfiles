---
name: repo-pointer
description: Use when the user wants to look in, point to, or open another repo by short name (e.g. "look in k8s-apps", "point to legacy k8s-apps", "open the munin-api repo"). Resolves the short name to the repo's readable path under ~/git so you can read and search it without the user typing the full path.
---

# Repo Pointer

Turn a short repo name into a concrete path to read and search.

## Steps

1. Run the resolver with the name the user gave (just the leaf name, e.g. `k8s-apps`).
   Add a second arg to target a specific worktree (matched by dir name or branch),
   e.g. `repo-resolve munin-api caching-otel`:

   ```
   ~/.scripts/repo-resolve.sh <name> [worktree]
   ```

   To see a repo's worktrees: `~/.scripts/repo-resolve.sh --worktrees <name>`.

2. Act on the exit code:
   - **0** — stdout is the absolute path. Announce it ("Looking in `<path>`.") and use that path as the base for all `Read`/`Grep`/`Glob`/`Bash` calls for this task. The user can run `/add-dir <path>` once to silence permission prompts; mention that if prompts appear.
   - **3** (ambiguous) — candidate paths are on stderr. Show them, ask which one the user means, then use the chosen path directly.
   - **4** (none) — no match. Tell the user and offer `ls ~/git` to list options.

3. Keep using the resolved path for the rest of the task. Re-run the resolver if the user points at a different repo.

## Notes
- Regular clones resolve to the repo dir. Bare-with-worktrees repos resolve to the **default-branch worktree** inside (where the code lives), not the bare container root.
- Always state the resolved path so the user knows where you're reading from.
