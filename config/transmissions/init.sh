#!/bin/sh
# Create or refresh a transmissions mailbox in a project directory.
#
#   sh init.sh PROJECT_DIR [PROJECT_NAME]
#
# Run by `mosh tx init` on the host. Also works inside a container:
#   sh /mosh-config/transmissions/init.sh /workspace NAME
#
# Safe to re-run. It refreshes PROTOCOL.md and tx.sh from this directory,
# keeps the existing project name unless a new one is given, and never touches
# mail. POSIX sh, so it runs on macOS's /bin/sh and in the container.
set -eu

SRC=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
proj=${1:-}
name=${2:-}

if [ -z "$proj" ] || [ ! -d "$proj" ]; then
  echo "usage: init.sh PROJECT_DIR [PROJECT_NAME]" >&2
  exit 1
fi
proj=$(CDPATH='' cd -- "$proj" && pwd)
tx="$proj/transmissions"

# The project folder is writable from inside a mosh container, so anything in
# the mailbox may have been replaced with a symlink to somewhere else on the
# host. Writing through one would let the container overwrite host files, so
# refuse if any path this script writes to is a symlink.
for p in "$tx" "$tx/tx.sh" "$tx/PROTOCOL.md" "$tx/.gitignore" \
         "$tx/to-terminal" "$tx/to-desktop"; do
  if [ -L "$p" ]; then
    echo "init.sh: refusing to write through a symlink: $p" >&2
    exit 1
  fi
done
for d in .tmp to-terminal/new to-terminal/read to-desktop/new to-desktop/read; do
  if [ -L "$tx/$d" ] || [ -L "$tx/$d/.keep" ]; then
    echo "init.sh: refusing to write through a symlink in: $tx/$d" >&2
    exit 1
  fi
done

action=created
if [ -f "$tx/PROTOCOL.md" ]; then
  action=updated
  if [ -z "$name" ]; then
    name=$(sed -n 's/^project: *//p' "$tx/PROTOCOL.md" | head -n 1)
  fi
fi
[ -n "$name" ] || name=$(basename "$proj")

# Inside a container the project root is /workspace, which says nothing about
# the project. Insist on a real name so a desktop session can tell mailboxes apart.
if [ "$name" = workspace ] || [ "$name" = PROJECT_NAME ]; then
  echo "init.sh: give a project name, e.g. init.sh $proj my-project" >&2
  exit 1
fi
# The name is substituted into PROTOCOL.md with sed; keep it to safe characters.
name=$(printf '%s' "$name" | tr -c 'A-Za-z0-9._-' '-')

for d in .tmp to-terminal/new to-terminal/read to-desktop/new to-desktop/read; do
  mkdir -p "$tx/$d"
  [ -e "$tx/$d/.keep" ] || : > "$tx/$d/.keep"
done

cp "$SRC/tx.sh" "$tx/tx.sh"
chmod +x "$tx/tx.sh"
sed "s/^project: .*/project: $name/" "$SRC/PROTOCOL.md" > "$tx/PROTOCOL.md"

# Drafts are scratch files; keep them (and the .keep placeholder rule) out of git.
[ -f "$tx/.gitignore" ] || printf '.tmp/*\n!.tmp/.keep\n' > "$tx/.gitignore"

echo "$action transmissions mailbox: $tx (project: $name)"
