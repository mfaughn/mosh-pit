---
name: tx-send
description: Send a transmission from this container session to the Claude desktop app (research side) via the project's transmissions/to-desktop/new/ — findings, results, questions, requests for research, or responses to desktop requests. Use when the user runs /tx-send or asks to "send/tell/report this to the desktop".
---

# tx-send: send a transmission to the desktop

The rules are in `transmissions/PROTOCOL.md`.

## Find the mailbox

```
ls /workspace/transmissions/PROTOCOL.md /workspace/*/transmissions/PROTOCOL.md 2>/dev/null
```

- **One hit:** its directory is `$MB`.
- **Several hits:** pick by the `project:` line in each `PROTOCOL.md`; ask if
  that's unclear.
- **No hits:** the project has no mailbox yet. Offer to create one (ask
  first): `sh /mosh-config/transmissions/init.sh /workspace <project-name>`.
  With several projects mounted, use `/workspace/<dir>` in place of
  `/workspace`. On the host, `mosh tx init` does the same job.

## Steps

1. Work out what to send from the user's instruction and the current context.
   If the user only said `/tx-send`, propose a title and summary based on the
   recent work and confirm them before sending.
2. Create a draft: `sh $MB/tx.sh draft terminal <short-slug>`.
   This prints a path in `$MB/.tmp/` with the frontmatter already filled in
   (id, from, to, created).
3. Edit the draft:
   - `type`: `info`, `request` (you want the desktop to research or answer
     something), or `response` (an answer to a desktop request).
   - `title`, `summary`: replace both TODOs. The summary is one or two
     sentences, enough to decide whether to open the file.
   - `in-reply-to`: the id being answered or followed up on, if any.
   - `closes`: `[<id>, ...]` for desktop requests this resolves.
   - `priority: high` only if it is blocking or urgent.
   - `refs`: paths relative to the project root (never `/workspace/...`; the
     desktop sees a different path), plus URLs and commits.
   - Body: `## Context`, `## Content`, `## Asks` (for requests: numbered and
     concrete), `## Sources`. The desktop session can read the project files
     but has no memory of this terminal session, so write the transmission
     to make sense on its own. Include exact error messages, versions, file
     paths, and line numbers where they matter.
   - Keep every frontmatter field on one line, write lists inline, and don't
     add comments.
4. Deliver it: `sh $MB/tx.sh deliver <draft-path>`. If the script rejects it,
   fix the frontmatter and run it again. Never write directly into
   `to-desktop/new/`.
5. Tell the user the id and title that were sent.

To find the ids of requests waiting on this side, run `sh $MB/tx.sh open`
(look for `desktop->terminal request`).
