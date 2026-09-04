#!/usr/bin/env bash
# Publish to the sandbox: the srt policy, and the runtime copy of everything the
# sandbox calls. Run by install.sh, and runnable on its own to publish a skill or
# a shared-script edit without restowing $HOME or going near brew. Idempotent.
#
# This repo is private to $USER; the sandbox account cannot read /Users/$USER.
# What it needs is deployed outward as copies — copies, not symlinks, so an agent
# write in the share never reaches anything the host runs. The copy has to live
# *inside* the share: sv's own seatbelt denies reads everywhere under /Users
# except the share and the sandbox home, so no other location is readable there.
set -Eeuo pipefail

# Repo root. `pwd -P` first: ~/.scripts is a symlink to scripts/, so the logical
# parent of $0's dir is $HOME rather than the repo.
cd "$(dirname "$0")" && cd "$(pwd -P)/.."

SHARE="/Users/Shared/sv-$USER"
if [ ! -d "$SHARE" ]; then
  # Not an error on a fresh machine — the share only exists after `sv build`.
  # Said out loud because a silent skip and a working deploy look identical.
  echo "no $SHARE — skipped the sandbox deploy (run: sv build)" >&2
  exit 0
fi

# srt reads the allowlist as sandvault-$USER, so it cannot live in this repo.
# Kept outside $SHARE, where `sv -r`'s ACL walk never reaches it; /Users/Shared
# is sticky, so only this account can replace the dir.
POLICY="/Users/Shared/$USER-policy"
install -d -m 755 "$POLICY"
install -m 644 "$PWD/scripts/lib/srt-settings.json" "$POLICY/srt-settings.json"

# The sandbox's ~/.scripts, skills, commands and agent settings.
# sandvault-sync.sh wires the sandbox home to this copy.
# Rebuilt from scratch each run: --delete only prunes inside a synced subtree,
# so anything deployed by an older layout would linger here forever.
RUNTIME="$SHARE/agent-runtime"
rm -rf "$RUNTIME"
mkdir -p "$RUNTIME/scripts"
rsync -a --exclude .git "$PWD/scripts/shared/" "$RUNTIME/scripts/shared/"
rsync -a --exclude .git "$PWD/agents/"         "$RUNTIME/agents/"

echo "deployed to the sandbox: $POLICY/srt-settings.json + $RUNTIME"
