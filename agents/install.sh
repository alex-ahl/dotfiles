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

for acct in "$HOME/.claude-account1" "$HOME/.claude-account2"; do
  mkdir -p "$acct/commands" "$acct/skills"
  # Claude reads global instructions from CLAUDE.md at the config-dir level.
  # (A future opencode agent would get GLOBAL symlinked as its own AGENTS.md.)
  ln -sfn "$GLOBAL" "$acct/CLAUDE.md"
  for f in "$COMMANDS"/*.md; do
    ln -sfn "$f" "$acct/commands/$(basename "$f")"
  done
  for d in "$SKILLS"/*/; do
    ln -sfn "${d%/}" "$acct/skills/$(basename "$d")"
  done
  # Drop links whose source is gone (skill deleted or renamed upstream). Without
  # this, a removed skill stays listed and loadable until someone deletes the
  # link by hand. Only broken symlinks go — a real file here isn't ours to touch.
  for l in "$acct/commands"/* "$acct/skills"/*; do
    [ -L "$l" ] && [ ! -e "$l" ] && rm -- "$l" && echo "pruned stale link: $l"
  done
done

echo "linked global instructions + commands + skills into ~/.claude-account{1,2}"
