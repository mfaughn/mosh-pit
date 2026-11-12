#!/usr/bin/env bash
# Link UADF into ~/.claude on the host so Claude Code outside mosh containers can use it.
#
# Creates symlinks, so edits in this repo take effect immediately:
#   ~/.claude/uadf               -> <repo>/config/uadf
#   ~/.claude/skills/uadf-<name> -> <repo>/config/uadf/skills/uadf-<name>
#
# Anything already at those paths that is not a symlink is moved aside to
# <path>.backup.<timestamp> rather than deleted. Safe to run more than once.
#
# Mosh containers don't need this: launch.sh copies the files in on every launch.
set -euo pipefail

uadf_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
claude_dir="$HOME/.claude"
stamp="$(date +%Y%m%d%H%M%S)"

# link_path SOURCE TARGET
# Point TARGET at SOURCE, backing up a real file or directory already at TARGET.
link_path() {
  local source="$1" target="$2"
  if [[ -e "$target" && ! -L "$target" ]]; then
    mv "$target" "$target.backup.$stamp"
    echo "Backed up $target -> $target.backup.$stamp"
  fi
  ln -sfn "$source" "$target"
  echo "Linked $target -> $source"
}

mkdir -p "$claude_dir/skills"
link_path "$uadf_dir" "$claude_dir/uadf"
for skill in "$uadf_dir"/skills/uadf-*/; do
  name="$(basename "$skill")"
  link_path "${skill%/}" "$claude_dir/skills/$name"
done

old_commands="$claude_dir/commands/uadf"
if [[ -d "$old_commands" ]]; then
  echo
  echo "Old UADF commands are still at $old_commands."
  echo "Remove that directory, or each command will appear twice (as /uadf:uadf-* too)."
fi
