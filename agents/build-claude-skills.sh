#!/usr/bin/env bash
# Build build/claude-skills, the one skills dir Claude reads: a link per skill
# from shared/skills (any agent) and claude-skills (Claude only).
# Relative links, so the copy deploy-runtime.sh makes resolves in the sandbox too.
# Only links are replaced: Claude writes its claude.ai skill sync (synced/,
# .trash/) into this dir, and that stays. Run by deploy-runtime.sh, so adding or
# removing a skill takes a deploy. Idempotent.
set -euo pipefail
shopt -s nullglob
cd "$(dirname "$0")"                 # agents/

FARM=build/claude-skills

remove_links() {
  find "$FARM" -mindepth 1 -maxdepth 1 -type l -delete
}

link_skills_from() {
  local src="$1" skill
  for skill in "$src"/*/; do
    skill="${skill%/}"
    ln -s "../../$skill" "$FARM/${skill##*/}"
  done
}

mkdir -p "$FARM"
remove_links
link_skills_from shared/skills
link_skills_from claude-skills
