#!/usr/bin/env bash
# Print the end of the latest other Claude Code session that ran in a directory, from any
# account, so a new session can pick up where it stopped.
#
# Usage: last-session.sh [dir] [messages] [skip]
#   dir       the directory the session ran in (default: the current one)
#   messages  how many messages to show (default: 200)
#   skip      how many sessions to skip, newest first (default: 0, the latest)
set -euo pipefail
shopt -s nullglob

dir="${1:-$PWD}"
messages="${2:-200}"
skip="${3:-0}"
self="${CLAUDE_CODE_SESSION_ID:-}"
slug="${dir//[!a-zA-Z0-9]/-}"

sessions=()
for file in "$HOME"/.claude*/projects/"$slug"/*.jsonl; do
  [[ $(basename "$file" .jsonl) == "$self" ]] && continue
  sessions+=("$file")
done

if ((${#sessions[@]} == 0)); then
  echo "No other session found for $dir" >&2
  exit 1
fi

# Newest first. A read loop, since macOS's bash 3.2 has no mapfile.
newest=()
while IFS= read -r file; do newest+=("$file"); done < <(ls -t "${sessions[@]}")
sessions=("${newest[@]}")
if ((skip >= ${#sessions[@]})); then
  echo "Only ${#sessions[@]} other session(s) for $dir" >&2
  exit 1
fi
file="${sessions[$skip]}"

account="$(echo "$file" | sed -E 's#.*/(\.claude[^/]*)/projects/.*#\1#')"
echo "Session: $(basename "$file" .jsonl)"
echo "Account: $account"
echo "Last active: $(date -r "$file" '+%Y-%m-%d %H:%M')"
echo "Other sessions here: $((${#sessions[@]} - 1))"
echo "---"

# One JSON string per message, so tail counts messages rather than lines.
jq -c '
  select((.type == "user" or .type == "assistant") and (.isSidechain | not))
  | .type as $who
  | (.message.content | if type == "string" then [{type: "text", text: .}] else . end)
  | map(
      if .type == "text" then .text
      elif .type == "tool_use" then "[\(.name)] \(.input | tostring | .[0:240])"
      else empty end)
  | map(select(test("^<(local-command|command-name|system-reminder)") | not))
  | select(length > 0)
  | "\($who | ascii_upcase): \(join("\n") | .[0:3000])"
' "$file" | tail -n "$messages" | jq -r '., ""'
