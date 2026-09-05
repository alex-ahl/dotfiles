#!/usr/bin/env bash
# Link shared agent commands + skills into each agent's config dirs.
# Single agent (claude, two accounts) for now; a second would add target dirs to
# the loop (or later be driven by scripts/agents.d/). Idempotent; run by install.sh.
set -euo pipefail
cd "$(dirname "$0")"                 # agents/
REPO="$(cd .. && pwd)"

COMMANDS="$PWD/shared/commands"      # version-controlled command sources
SKILLS="$PWD/shared/skills"          # version-controlled skill sources
GLOBAL="$PWD/shared/AGENTS.md"      # global agent instructions

# Link a shared dir into an account. Whole-dir, not entry by entry: a link farm
# only picks up a *new* skill when it is rebuilt, and the sandbox's farm is
# rebuilt by sandvault-sync.sh rather than install.sh — so adding a skill
# silently needed a different command than editing one. A dir symlink makes both
# just a deploy. It also retires the stale-link prune this used to need: with the
# dir as the source, a deleted skill is simply gone.
link_dir() {
  local src="$1" dst="$2"
  # ln -sfn nests inside an existing real dir instead of replacing it, so the
  # old farm has to go first — but never anything that isn't ours.
  if [ -d "$dst" ] && [ ! -L "$dst" ]; then
    if [ -n "$(find "$dst" -mindepth 1 -maxdepth 1 ! -type l -print -quit)" ]; then
      echo "$dst holds real files — move them into agents/shared/ and re-run" >&2
      exit 1
    fi
    rm -rf "$dst"
  fi
  ln -sfn "$src" "$dst"
}

for acct in "$HOME/.claude-account1" "$HOME/.claude-account2"; do
  mkdir -p "$acct"
  # Claude reads global instructions from CLAUDE.md at the config-dir level.
  # (A future opencode agent would get GLOBAL symlinked as its own AGENTS.md.)
  ln -sfn "$GLOBAL" "$acct/CLAUDE.md"
  link_dir "$COMMANDS" "$acct/commands"
  link_dir "$SKILLS"   "$acct/skills"
done

# Plain ~/.claude — used by any agent started without CLAUDE_CONFIG_DIR — gets
# the instructions but not the dirs: `sv` installs its own sandvault-sv skill
# there, and a dir symlink would both hide it and send sv's next write into this
# repo.
mkdir -p "$HOME/.claude"
ln -sfn "$GLOBAL" "$HOME/.claude/CLAUDE.md"

echo "linked global instructions + commands + skills into ~/.claude-account{1,2}, instructions into ~/.claude"
