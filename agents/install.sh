#!/usr/bin/env bash
# Link shared agent commands + skills into each agent's config dirs.
# Kept simple: one agent (claude, two accounts) for now. A second agent would
# add its own target dirs to the loop (or, later, be driven by scripts/agents.d/).
# Idempotent — safe to re-run; run by the top-level install.sh.
set -euo pipefail
cd "$(dirname "$0")"                 # agents/
REPO="$(cd .. && pwd)"

COMMANDS="$PWD/shared/commands"      # version-controlled command sources
SKILLS="$REPO/scripts/skills"       # version-controlled skill sources

for acct in "$HOME/.claude-account1" "$HOME/.claude-account2"; do
  mkdir -p "$acct/commands" "$acct/skills"
  for f in "$COMMANDS"/*.md; do
    ln -sfn "$f" "$acct/commands/$(basename "$f")"
  done
  for d in "$SKILLS"/*/; do
    ln -sfn "${d%/}" "$acct/skills/$(basename "$d")"
  done
done

echo "linked agent commands + skills into ~/.claude-account{1,2}"
