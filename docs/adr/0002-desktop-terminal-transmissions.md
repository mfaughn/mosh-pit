# ADR-0002: Desktop app <-> container transmissions mailbox

## Status

Accepted (merged to `main` 2026-11-13 after review and security fixes; see the
review section at the end). Written by a Claude desktop app session on 2026-11-13
on branch `tx-transmissions`.

## Date

2026-11-13

## Context

The user does research in the Claude desktop app and implementation in mosh
containers. They want the two to exchange information **during** sessions,
not only at the start of a terminal session.

The only thing both sides can see is the project directory. The desktop app
can connect a host folder, and mosh bind-mounts that same folder at
`/workspace`. Neither side can notify the other. Claude Code has hooks; the
desktop app has none and only acts when the user sends a message.

Requirements agreed with the user:

- Per-project only. No shared, cross-project knowledge store.
- Two-way traffic, threaded replies, and a way to see which requests are
  still open.
- Manual triggering must always work. Automatic notification is a
  convenience on top.
- Keep it simple: plain files that can be inspected and committed to git.

## Decision

A mailbox folder, `<project>/transmissions/`, with a `new/` and a `read/`
directory for each direction:

```
transmissions/
  PROTOCOL.md  tx.sh  .tmp/
  to-terminal/new/  to-terminal/read/     desktop writes; container reads then archives
  to-desktop/new/   to-desktop/read/      container writes; desktop reads then archives
```

- **Messages**: one markdown file per transmission, named
  `YYYYMMDDTHHMMSSZ-slug.md` (UTC, so the two sides' clocks sort together).
  The filename without `.md` is the id. YAML frontmatter holds `id`, `from`,
  `to`, `created`, `type` (info|request|response), `title`, `summary`,
  `in-reply-to`, `closes`, `priority`, `refs`.
- **Who writes what**: a sender writes into `.tmp/` and renames the file
  into the recipient's `new/`, so a reader never sees a half-written file.
  Only the recipient moves files from `new/` to `read/`, and only after
  acting on them. Files are never edited after delivery.
- **Open requests**: a `request` is open until a later transmission lists
  its id in `closes:`. Status is worked out from the files; nothing is
  written back to the request.
- **Threads**: through `in-reply-to` only.
- **`tx.sh`**: a POSIX sh helper inside each mailbox that both sides use
  for every operation, so the rules are enforced in one place. `deliver`
  validates the frontmatter.
- **The marker**: `transmissions/PROTOCOL.md` marks a folder as having a
  mailbox. Its `project:` field lets a desktop session that has several
  folders connected tell the mailboxes apart.

### How it ships in mosh

| piece | location | reaches containers by |
|---|---|---|
| `tx-inbox`, `tx-send`, `tx-history` skills | `config/skills/` | the `launch.sh` skills loop, at every launch |
| `tx-check.sh` hook | `config/hooks/`, registered in `config/settings.json` | the `launch.sh` hooks sync, at every launch |
| `PROTOCOL.md`, `tx.sh`, `init.sh` | `config/transmissions/` | `mosh tx init`, copied into each project |
| desktop skill `tx-desktop` | the user's desktop app account | not in this repo |

The skills and the hook find mailboxes at `/workspace/transmissions` and
`/workspace/*/transmissions`, so multi-project launches work. When there is
no mailbox, the hook prints nothing and exits 0.

## Alternatives considered

- **Install into each project's `.claude/` from the host** (the first
  version of this kit). It works for single-project launches, but under
  multi-project launches the cwd is `/workspace`, so `/workspace/<p>/.claude`
  is not loaded and `$CLAUDE_PROJECT_DIR` points at `/workspace`. It would
  also mean a copy of the skills in every project. Rejected in favor of
  `config/`.
- **A cursor file per reader instead of `new/` and `read/` directories.**
  This loses mail if two messages arrive between checks and a reader reads
  only the newest one. Directories make "is anything unread?" a single
  `ls`. Rejected.
- **Recording status inside the request file.** That needs edits after
  delivery, possibly in a file the other side has already moved. Replaced
  by `closes:`.
- **A shared `CURRENT.md` digest.** Dropped: the container already carries
  knowledge across sessions (auto memory, the UADF journal), and the
  desktop keeps its own memory.
- **A shared MCP memory server.** More moving parts and harder to inspect
  than files. Not needed at this scale.

## Consequences

- Every container now runs `tx-check.sh` on SessionStart and on each
  prompt. Without a mailbox, that costs two glob checks.
- Changes to `config/transmissions/tx.sh` or `PROTOCOL.md` reach existing
  mailboxes only when `mosh tx init` is re-run in the project.
  `mosh tx status` warns when a mailbox's `tx.sh` is out of date.
- The desktop-side skill lives outside this repo. If the protocol changes,
  the desktop skill has to be updated to match, from a desktop session.
- `transmissions/` is meant to be committed (history and audit). Its own
  `.gitignore` excludes `.tmp/`.

## Review notes for the mosh-pit session

Verified on the desktop side, in a Linux sandbox, not in a real mosh
container:

- `bash -n` passes for `mosh` and `launch.sh`. ShellCheck is clean on the
  new sh files and on the new `cmd_tx`.
- An end-to-end mailbox exchange: draft, deliver, the hook notice,
  archive, a reply that closes the request, `open`, `thread`, `search`,
  and rejection of a bad delivery.
- The hook with single-project, multi-project, and no-mailbox layouts.
- The `launch.sh` sync loops, run against a stub `/mosh-config` and
  `$HOME`.

Not verified, so please check:

1. A real launch: the skills appear (`/tx-inbox` autocompletes), and the
   SessionStart hook output reaches the model's context. If a Claude Code
   version stops adding SessionStart/UserPromptSubmit stdout to context,
   the manual `/tx-inbox` still works.
2. Under auto mode, the classifier lets `sh /workspace/transmissions/tx.sh
   ...` and the `mv`s inside it through without prompting.
3. `mosh tx init` on macOS bash 3.2 and `/bin/sh`.
4. After merging, add a JOURNAL entry, and move this ADR's status to
   Accepted.

## Review by the mosh-pit session (2026-11-13)

Tested in a container with a scratch project: the full mailbox exchange, the hook
(single, multi and no mailbox), `mosh tx status` and `init` with a stub `podman`.
All worked. Two security problems were found and fixed:

1. **`mosh tx status` ran the project's `tx.sh` on the host.** The project folder is
   writable from inside the container, so the container could rewrite that script and
   have the host run it, as the user, at the next `mosh tx status`. Demonstrated, then
   fixed: `tx.sh` accepts `TX_ROOT`, and `mosh tx` runs mosh-pit's own copy with
   `TX_ROOT` pointing at the mailbox. It still warns when the project's copy differs.
2. **`init.sh` wrote through symlinks.** A container could replace `transmissions/tx.sh`
   (or a mail directory) with a symlink to a host file, which `mosh tx init` would then
   overwrite. Demonstrated, then fixed: `init.sh` refuses when any path it writes to is a
   symlink.

Open question for the desktop side: the same reasoning applies wherever the desktop
app runs `sh transmissions/tx.sh`. If that runs on the Mac rather than in a sandbox,
the desktop skill should run a trusted copy with `TX_ROOT` as well.

Decided with the user: the hook keeps announcing unread mail on every prompt. The
repetition is wanted as a reminder.

Still to verify after merging: a real launch (skills appear, hook output reaches the
model), auto mode letting `tx.sh` calls through, and `mosh tx init` on macOS bash 3.2.
