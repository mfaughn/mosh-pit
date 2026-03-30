#!/usr/bin/env bash
set -euo pipefail

# Read JSON from stdin
json=$(cat)

parts=()

# Field: Model ID (model_id)
raw=$(echo "$json" | jq -r '.model.id // empty' 2>/dev/null || echo "")
if [ -n "$raw" ]; then
  formatted="$raw"
  formatted="\033[36m${formatted}\033[0m"
  parts+=("$formatted")
fi

# Field: Context (context_used)
raw=$(echo "$json" | jq -r '.context_window.used_percentage // empty' 2>/dev/null || echo "")
if [ -n "$raw" ]; then
  formatted="${raw}%"
  formatted="\033[32m${formatted}\033[0m"
  parts+=("$formatted")
fi

# Field: Duration (duration)
raw=$(echo "$json" | jq -r '.total_duration_ms // empty' 2>/dev/null || echo "")
if [ -n "$raw" ]; then
  total_sec=$(( raw / 1000 ))
  mins=$(( total_sec / 60 ))
  secs=$(( total_sec % 60 ))
  if [ "$mins" -gt 0 ]; then
    formatted="${mins}m ${secs}s"
  else
    formatted="${secs}s"
  fi
  parts+=("$formatted")
fi

# Field: Branch (branch)
raw=$(echo "$json" | jq -r '.worktree.branch // empty' 2>/dev/null || echo "")
if [ -n "$raw" ]; then
  formatted="$raw"
  formatted="\033[35m${formatted}\033[0m"
  parts+=("$formatted")
fi

# Join parts with separator
sep=" | "
result=""
for part in "${parts[@]}"; do
  if [ -n "$result" ]; then
    result+="$sep"
  fi
  result+="$part"
done

echo -e "$result"
