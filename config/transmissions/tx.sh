#!/bin/sh
# tx.sh - helper for the desktop <-> terminal transmission mailbox.
# POSIX sh; works on macOS and Linux (incl. busybox). See PROTOCOL.md.
set -eu

ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
DIRS="to-terminal/new to-terminal/read to-desktop/new to-desktop/read"

die() { echo "tx.sh: $*" >&2; exit 1; }

ensure_dirs() {
  for d in $DIRS .tmp; do mkdir -p "$ROOT/$d"; done
}

valid_side() { [ "$1" = desktop ] || [ "$1" = terminal ]; }
other_side() { if [ "$1" = desktop ]; then echo terminal; else echo desktop; fi; }

# field FILE KEY -> value of a frontmatter key (surrounding quotes stripped)
field() {
  awk -v k="$2" '
    NR==1 { sub(/\r$/,""); if ($0 != "---") exit; next }
    { sub(/\r$/,"") }
    $0 == "---" { exit }
    {
      i = index($0, ":")
      if (i > 0 && substr($0, 1, i-1) == k) {
        v = substr($0, i+1)
        sub(/^[ \t]+/, "", v); sub(/[ \t]+$/, "", v)
        if (v ~ /^".*"$/ || v ~ /^\047.*\047$/) v = substr(v, 2, length(v)-2)
        print v; exit
      }
    }' "$1"
}

# list items of an inline YAML list value: "[a, b]" -> lines a, b
list_items() {
  printf '%s\n' "$1" | sed -e 's/^\[//' -e 's/\]$//' | tr ',' '\n' |
    sed -e 's/^[ \t"]*//' -e 's/[ \t"]*$//' | grep -v -e '^$' -e '^null$' || true
}

# all transmission files, sorted by id (= chronological). Output: paths.
all_files() {
  for d in $DIRS; do
    for f in "$ROOT/$d"/*.md; do
      [ -e "$f" ] || continue
      printf '%s\t%s\n' "$(basename "$f" .md)" "$f"
    done
  done | sort | cut -f2-
}

path_of() {
  for d in $DIRS; do
    [ -e "$ROOT/$d/$1.md" ] && { echo "$ROOT/$d/$1.md"; return 0; }
  done
  return 1
}

summary_line() {
  f=$1
  case "$f" in */new/*) st="NEW" ;; *) st="read" ;; esac
  pr=$(field "$f" priority); [ "$pr" = high ] && pr=" HIGH" || pr=""
  printf '%s  [%s->%s %s %s%s]  %s\n' "$(basename "$f" .md)" \
    "$(field "$f" from)" "$(field "$f" to)" "$(field "$f" type)" "$st" "$pr" \
    "$(field "$f" title)"
}

cmd=${1:-help}; [ $# -gt 0 ] && shift

case "$cmd" in
  root) echo "$ROOT" ;;

  field) [ $# -eq 2 ] || die "usage: field FILE KEY"; field "$1" "$2" ;;

  draft)
    [ $# -eq 2 ] || die "usage: draft FROM SLUG"
    valid_side "$1" || die "FROM must be desktop or terminal"
    ensure_dirs
    slug=$(printf '%s' "$2" | tr '[:upper:]' '[:lower:]' | sed -e 's/[^a-z0-9]\{1,\}/-/g' -e 's/^-//' -e 's/-$//' | cut -c1-50)
    [ -n "$slug" ] || slug=note
    ts=$(date -u +%Y%m%dT%H%M%SZ); iso=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    id="$ts-$slug"; n=2
    while path_of "$id" >/dev/null || [ -e "$ROOT/.tmp/$id.md" ]; do id="$ts-$slug-$n"; n=$((n+1)); done
    out="$ROOT/.tmp/$id.md"
    cat > "$out" <<EOF
---
id: $id
from: $1
to: $(other_side "$1")
created: $iso
type: info
title: TODO
summary: TODO
in-reply-to: null
closes: []
priority: normal
refs: []
---

## Context

## Content

EOF
    echo "$out" ;;

  deliver)
    [ $# -eq 1 ] || die "usage: deliver PATH"
    f=$1; [ -f "$f" ] || die "no such file: $f"
    ensure_dirs
    base=$(basename "$f" .md)
    id=$(field "$f" id); from=$(field "$f" from); to=$(field "$f" to)
    type=$(field "$f" type); title=$(field "$f" title); summ=$(field "$f" summary)
    [ "$id" = "$base" ] || die "id '$id' does not match filename '$base'"
    printf '%s' "$id" | grep -Eq '^[0-9]{8}T[0-9]{6}Z-[a-z0-9-]+$' || die "bad id format: $id"
    if ! valid_side "$from" || ! valid_side "$to" || [ "$from" = "$to" ]; then die "from/to must be desktop/terminal and differ"; fi
    case "$type" in info|request|response) ;; *) die "type must be info|request|response" ;; esac
    [ -n "$title" ] && [ "$title" != TODO ] || die "title missing"
    [ -n "$summ" ] && [ "$summ" != TODO ] || die "summary missing"
    for r in $(list_items "$(field "$f" closes)") $(list_items "$(field "$f" in-reply-to)"); do
      path_of "$r" >/dev/null || echo "tx.sh: warning: referenced id not found: $r" >&2
    done
    path_of "$id" >/dev/null && die "id already delivered: $id"
    case "$(CDPATH='' cd -- "$(dirname -- "$f")" && pwd)" in
      "$ROOT/.tmp") staged=$f ;;
      *) staged="$ROOT/.tmp/$base.md"; cp "$f" "$staged.part"; mv "$staged.part" "$staged" ;;
    esac
    dest="$ROOT/to-$to/new/$base.md"
    mv "$staged" "$dest"
    echo "$dest" ;;

  pending)
    if [ $# -ne 1 ] || ! valid_side "$1"; then die "usage: pending desktop|terminal"; fi
    for f in "$ROOT/to-$1/new"/*.md; do [ -e "$f" ] && echo "$f"; done | sort ;;

  count)
    if [ $# -ne 1 ] || ! valid_side "$1"; then die "usage: count desktop|terminal"; fi
    n=0; for f in "$ROOT/to-$1/new"/*.md; do [ -e "$f" ] && n=$((n+1)); done; echo $n ;;

  archive)
    if [ $# -lt 2 ] || ! valid_side "$1"; then die "usage: archive desktop|terminal ID..."; fi
    me=$1; shift; ensure_dirs
    for id in "$@"; do
      id=$(basename "$id" .md)
      src="$ROOT/to-$me/new/$id.md"
      [ -e "$src" ] || die "not in to-$me/new: $id"
      mv "$src" "$ROOT/to-$me/read/$id.md" && echo "archived $id"
    done ;;

  list)
    all_files | while IFS= read -r f; do summary_line "$f"; done ;;

  open)
    closed=$(all_files | while IFS= read -r f; do list_items "$(field "$f" closes)"; done | sort -u)
    all_files | while IFS= read -r f; do
      [ "$(field "$f" type)" = request ] || continue
      id=$(basename "$f" .md)
      printf '%s\n' "$closed" | grep -qxF "$id" && continue
      summary_line "$f"
    done ;;

  thread)
    [ $# -eq 1 ] || die "usage: thread ID"
    want=$(basename "$1" .md); path_of "$want" >/dev/null || die "unknown id: $want"
    map=$(all_files | while IFS= read -r f; do
      p=$(field "$f" in-reply-to); [ -n "$p" ] || p=null
      printf '%s %s\n' "$(basename "$f" .md)" "$p"; done)
    ids=$(printf '%s\n' "$map" | awk -v w="$want" '
      { order[NR]=$1; par[$1]=$2 }
      function root(x,  n) { n=0; while ((x in par) && par[x]!="null" && (par[x] in par) && n<1000) { x=par[x]; n++ } return x }
      END { r=root(w); for (i=1;i<=NR;i++) if (root(order[i])==r) print order[i] }')
    for id in $ids; do summary_line "$(path_of "$id")"; done ;;

  search)
    [ $# -eq 1 ] || die "usage: search REGEX"
    all_files | while IFS= read -r f; do
      grep -qiE -- "$1" "$f" && summary_line "$f"; done; true ;;

  path) [ $# -eq 1 ] || die "usage: path ID"; path_of "$(basename "$1" .md)" || die "unknown id: $1" ;;

  init) ensure_dirs; echo "initialized $ROOT" ;;

  help|*)
    sed -n '/^## tx.sh reference/,$p' "$ROOT/PROTOCOL.md" 2>/dev/null || echo "see PROTOCOL.md" ;;
esac
