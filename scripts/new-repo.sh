#!/usr/bin/env bash
# Create a GitHub repo and open it as a wsg workspace. Bound to `prefix + G`.
# Prompts for owner (your account or one of your orgs), name and visibility,
# then: gh repo create (with a README — clone-bare needs a first commit),
# default branch renamed to master, a development branch off it made the
# default, rulesets (neither deletable, master no force push), clone-bare into
# ~/git/personal or ~/git/work, and workspace.sh in the development worktree.
# Owner picks the folder the same way gh-token.sh picks the token: your own
# login is personal, every org is work.
# Must run inside a display-popup (-E) so fzf has a terminal.
set -euo pipefail

me=$(gh api user --jq .login)
owner=$({ echo "$me"; gh org list; } | fzf --reverse --prompt 'owner> ') || exit 0
[ "$owner" = "$me" ] && scope=personal || scope=work

printf 'repo name: '; IFS= read -r name
[ -n "$name" ] || exit 0
repo="$owner/$name"
dir="$HOME/git/$scope/$name"
# Before creating anything remote: clone-bare refuses an existing dir, and a
# repo created on GitHub but never cloned is easy to lose track of.
[ -e "$dir" ] && { echo "already exists: $dir" >&2; exit 1; }

visibility=$(printf 'private\npublic\n' | fzf --reverse --prompt 'visibility> ') || exit 0

printf 'create %s (%s) in ~/git/%s? [y/N] ' "$repo" "$visibility" "$scope"
IFS= read -r ok
case "$ok" in [yY]*) ;; *) exit 0 ;; esac

gh repo create "$repo" "--$visibility" --add-readme

# --add-readme commits to the account's default branch name (usually main).
init=$(gh api "repos/$repo" --jq .default_branch)
[ "$init" = master ] \
  || gh api -X POST "repos/$repo/branches/$init/rename" -f new_name=master >/dev/null
sha=$(gh api "repos/$repo/git/ref/heads/master" --jq .object.sha)
gh api "repos/$repo/git/refs" -f ref=refs/heads/development -f sha="$sha" >/dev/null
# development is the default: PRs target it, master only takes releases.
gh api -X PATCH "repos/$repo" -f default_branch=development >/dev/null

ruleset() {  # $1 = branch, $2 = JSON array of rules
  gh api -X POST "repos/$repo/rulesets" --input - >/dev/null <<EOF
{"name": "$1", "target": "branch", "enforcement": "active",
 "conditions": {"ref_name": {"include": ["refs/heads/$1"], "exclude": []}},
 "rules": $2}
EOF
}
# GitHub Free has no rulesets on private repos: warn and carry on, since the
# repo itself is fine. The pause keeps the warning on screen — workspace.sh
# switches client and closes the popup.
if ! err=$({ ruleset master '[{"type": "deletion"}, {"type": "non_fast_forward"}]' \
             && ruleset development '[{"type": "deletion"}]'; } 2>&1); then
  printf '\nbranch protection NOT applied:\n%s\n\n[press enter to continue] ' "$err"
  read -r _
fi

# ssh URL: the commit-identity rules in ~/.gitconfig.local match on it.
(cd "$HOME/git/$scope" && "$HOME"/.scripts/clone-bare.sh "git@github.com:$repo.git")
# clone-bare makes worktrees for the default branch (development) + review.
git -C "$dir" worktree add master master

cd "$dir/development" && exec "$HOME"/.scripts/workspace.sh
