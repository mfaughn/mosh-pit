#!/bin/sh
# Claude Code hook (SessionStart and UserPromptSubmit, registered in
# config/settings.json): announce unread transmissions from the Claude desktop
# app. Claude Code adds this hook's stdout to the session's context.
#
# It looks for mailboxes at /workspace/transmissions and
# /workspace/*/transmissions (multi-project launches). It prints nothing when
# there is no mailbox or nothing is unread, so projects without a mailbox pay
# only for a couple of stat calls. It always exits 0, so it can never block a
# prompt.

cat >/dev/null 2>&1 || true   # drain the hook's JSON input

base=${MOSH_WORKSPACE:-/workspace}
out=""
total=0
for proto in "$base/transmissions/PROTOCOL.md" "$base"/*/transmissions/PROTOCOL.md; do
  [ -f "$proto" ] || continue
  mb=$(dirname "$proto")
  project=$(sed -n 's/^project: *//p' "$proto" 2>/dev/null | head -n 1)
  n=0
  for f in "$mb/to-terminal/new"/*.md; do
    [ -e "$f" ] || continue
    n=$((n + 1))
    if [ $n -le 5 ]; then
      title=$(sed -n 's/^title: *//p' "$f" 2>/dev/null | head -n 1)
      prio=""
      grep -q '^priority: *high' "$f" 2>/dev/null && prio=" [HIGH]"
      out="$out
  - ${project:-?}: $(basename "$f" .md)$prio: $title"
    fi
  done
  total=$((total + n))
done

[ $total -eq 0 ] && exit 0
echo "[transmissions] $total unread transmission(s) from the Claude desktop session:$out
Mention this to the user and offer to process them with the tx-inbox skill."
exit 0
