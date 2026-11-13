---
project: PROJECT_NAME
protocol-version: 1
---

# Transmission protocol: Claude desktop app <-> Claude Code (terminal)

This directory is a two-way mailbox between a Claude desktop app session (used
for research) and Claude Code sessions (used for implementation) working on the
same project. It is the single source of truth for how the mailbox works; the
skills on both sides defer to this file.

The presence of `transmissions/PROTOCOL.md` is what marks a folder as having a
mailbox. The `project:` field above names it, so a desktop session connected to
several folders can tell them apart.

## Creating and updating a mailbox

The canonical copies of `PROTOCOL.md` and `tx.sh` live in the mosh-pit repo at
`config/transmissions/`. To create a mailbox, or to refresh `PROTOCOL.md` and
`tx.sh` in an existing one (mail and the project name are kept):

- on the host, from the project directory: `mosh tx init [project-dir] [name]`
- inside a mosh container: `sh /mosh-config/transmissions/init.sh /workspace NAME`

In a mosh container the mailbox is at `/workspace/transmissions`, or at
`/workspace/<project>/transmissions` when several projects are mounted.

## Layout

```
transmissions/
  PROTOCOL.md            this file
  tx.sh                  helper script (POSIX sh) used by both sides
  .tmp/                  staging area for drafts; never read as mail
  to-terminal/new/       desktop writes here; terminal reads, then moves to read/
  to-terminal/read/      archive of processed desktop->terminal mail
  to-desktop/new/        terminal writes here; desktop reads, then moves to read/
  to-desktop/read/       archive of processed terminal->desktop mail
```

## Ownership rules

- The sender creates a file in the recipient's `new/` folder. It does so by
  writing in `.tmp/` and then renaming the file into place, so a file never
  appears half-written.
- Only the recipient moves files from `new/` to `read/`.
- Nobody edits a transmission once it has been sent. To correct or update one,
  send a new transmission with `in-reply-to:` pointing at the original.
- Move a file to `read/` only after acting on it. If a session is
  interrupted, the file stays in `new/` and will be seen again.
- Being in `read/` means "seen". It does not mean "done". Whether a request is
  still open is tracked separately (see Open requests).

## Filenames and IDs

`YYYYMMDDTHHMMSSZ-short-slug.md`, with the timestamp in UTC (for example
`20261105T213245Z-hl7-0467-sources.md`). The filename without `.md` is the
transmission's **id**. Sorting by filename sorts by time.

## Frontmatter

Each transmission starts with YAML frontmatter. Use one line per field, write
lists inline (`[a, b]`), and don't put `#` comments inside the frontmatter.

```yaml
---
id: 20261105T213245Z-hl7-0467-sources
from: desktop
to: terminal
created: 2026-11-05T21:32:45Z
type: request
title: Sources for Table 0467 modifier edit codes
summary: Found the authoritative list in the CMS I/OCE spec; please check the CLD in the repo against it.
in-reply-to: null
closes: []
priority: normal
refs: [docs/cld/0467.md, https://www.cms.gov/medicare/coding-billing/outpatient-code-editor-oce]
---
```

| field         | required | meaning |
|---------------|----------|---------|
| `id`          | yes | Must match the filename without `.md`. |
| `from`, `to`  | yes | `desktop` or `terminal`, and they must differ. |
| `created`     | yes | ISO-8601 time in UTC. |
| `type`        | yes | `info` (FYI), `request` (asks the other side to do or answer something), or `response` (an answer to something). |
| `title`       | yes | Short headline. |
| `summary`     | yes | One or two sentences, enough for the reader to decide whether to open the full file. |
| `in-reply-to` | no  | The id this transmission answers or follows up on (`null` if none). This field is what links a thread together. |
| `closes`      | no  | Ids of requests this transmission resolves. Any type of transmission can close a request. |
| `priority`    | no  | `normal` (default) or `high`. |
| `refs`        | no  | Paths relative to the project root, URLs, or citations. |

## Body

Use whichever of these sections apply:

```
## Context      why this is being sent; what the reader needs to know first
## Content      findings, decisions, results, data
## Asks         (requests only) numbered, concrete asks
## Sources      citations, links, file paths
```

Write each transmission so it makes sense on its own. The reading session may
have no memory of the conversation that produced it. Give file paths relative
to the project root, because the two sides see different absolute paths.

## Open requests

A request is **open** until a later transmission lists its id in `closes:`.
To see what's open, run `sh transmissions/tx.sh open`. To close a request
without doing it, send a short `response` that explains why and lists the
request in `closes:`.

## tx.sh reference

Run from anywhere: `sh <path-to>/transmissions/tx.sh <command>`.

```
draft FROM SLUG            create a skeleton in .tmp/ (FROM = desktop|terminal); prints its path
deliver PATH               check the frontmatter, then move the draft into the recipient's new/
pending ME                 list paths of unread mail for ME (oldest first)
count ME                   number of unread items for ME
archive ME ID...           move processed items from to-ME/new/ to to-ME/read/
list                       one line per transmission (all directions/states), oldest first
open                       requests not yet closed
thread ID                  every transmission in the thread containing ID
search REGEX               ids of transmissions whose text matches (case-insensitive)
path ID                    path of a transmission file
field FILE KEY             print one frontmatter field
root                       print the transmissions directory
init                       create any missing subdirectories
```
