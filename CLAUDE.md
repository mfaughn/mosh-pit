# mosh-pit

`mosh` is a bash script, run on the macOS host, that gives each project its own Podman
container running Claude Code. `config/` is the Claude Code configuration shared by every
container: the global `CLAUDE.md`, `settings.json`, agents and UADF.

## Where a change takes effect

- **`config/`** is mounted read-only at `/mosh-config`, and `config/launch.sh` copies it
  into `~/.claude` on every launch. Edits apply at the next `mosh` launch, with no rebuild
  and no `mosh fresh`. This copy merges files in, so a file deleted from `config/` stays
  in existing containers until removed there.
- **Environment variables (`.env`) and port mappings** are fixed when the container is
  created. Changing them needs `mosh fresh`.
- **`mosh build`** is rarely needed: the Containerfile copies only
  `config/git-credential-helper`. Use `--no-cache` to pick up a new base image.
- **`~/.claude` is a named volume.** It survives `mosh fresh` (sessions, plugins, auto
  memory). The Claude Code binary is in `~/.local`, on the container's own layer, so
  `mosh fresh` removes it and the launch reinstalls it. The binary and plugin state can
  drift apart.
- **`/workspace` is a bind mount of the host project.** Destructive commands there change
  the host's files. The container does not protect them.

## Writing shell code here

- `mosh` must run on macOS's bash 3.2: no associative arrays, and no `"${arr[@]}"` on an
  empty array under `set -u`.
- A function whose stdout is its return value must send messages to stderr.
- There is no test suite. Check with `shellcheck` and `bash -n`, and run changed paths
  with stubs or an isolated `CLAUDE_CONFIG_DIR` (`claude -p` works there). Some
  shellcheck notes predate current work. Judge only the lines you changed.

## Claude Code behavior verified in this setup

- `launch.sh` starts Claude Code in auto mode (`--permission-mode auto`). The classifier
  works through the gateway (tested 2026-11-12). Auto mode ignores broad allow rules
  such as `Bash(*)`.
- Deny rules apply before the classifier, and in every mode including bypass. A
  bare-name deny (`deny: ["WebSearch"]`) removes the tool from the main session and all
  subagents.
- A `Write(path)` deny rule never matches anything. To protect a path, write the rule
  against `Edit(path)` and `Read(path)`.
- The gateway is NIST's LiteLLM, backed by Vertex AI. Its `/v1/models` context windows are
  wrong. For model, context-window and auth details, see the 2026-09 entries in
  `JOURNAL_ARCHIVE.md`.

## Journal

This project uses UADF: `JOURNAL.md` for handoffs, `JOURNAL_ARCHIVE.md` for older
entries, `docs/adr/` for decisions.
