---
name: tx-history
description: Search and browse past transmissions between the Claude desktop app and this container session (both directions, read and unread) in the project's transmissions/ folder. Use when the user runs /tx-history, asks what the desktop said earlier about something, wants a thread reconstructed, or asks which requests are still open.
---

# tx-history: browse earlier transmissions

Everything here is read-only: don't move, edit, or archive anything. Use
**tx-inbox** for mail that hasn't been processed yet.

## Find the mailbox

```
ls /workspace/transmissions/PROTOCOL.md /workspace/*/transmissions/PROTOCOL.md 2>/dev/null
```

With one hit, its directory is `$MB`. With several, pick by the `project:`
line in each `PROTOCOL.md`, or ask. With none, the project has no mailbox.

## Tools

```
sh $MB/tx.sh list            # everything, oldest first, one line each
sh $MB/tx.sh search REGEX    # transmissions whose text matches (case-insensitive)
sh $MB/tx.sh thread ID       # the whole conversation containing ID
sh $MB/tx.sh open            # requests not yet closed (both directions)
sh $MB/tx.sh path ID         # file path, so you can read it
```

## How to search

1. **Check for later transmissions that change it.** Before relying on a
   transmission, run `thread <id>`. A later message in the same thread, or a
   later `response` that lists it in `closes`, may correct or replace it.
   Usually the most recent word in a thread is the one that counts.
2. When reporting back, cite transmission ids so the user can look them up.
3. If the history doesn't answer the question, say so. Offer to ask the
   desktop side with **tx-send** (`type: request`).
