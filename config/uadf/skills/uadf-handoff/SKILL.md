---
name: uadf-handoff
description: End a UADF session. Commits the session's work, appends a handoff entry to JOURNAL.md, and commits the journal last.
disable-model-invocation: true
---

# Write a UADF session handoff

Invoking this skill is the user's request to commit. Follow the commit steps below
without asking for separate permission, except where they say to ask.

## 1. Commit the session's work

Run `git status` and `git diff --stat`, and list untracked files.

- **On `main`:** before writing the journal entry, go through the uncommitted changes with
  the user and agree what should be committed and what should not.
- **On any other branch:** commit the work yourself. Decide whether it belongs in one
  commit or several, and ask the user when you're unsure.
- **On every branch:** don't commit secrets (`.env`, keys, tokens), generated output, or
  untracked files that look accidental. List them and ask.

Use the project's normal commit-message style, not a generic "WIP" message.

## 2. Write the entry

Append to `JOURNAL.md`, using this structure. Leave out a section only if it would be
empty.

```markdown
## Session Handoff — YYYY-MM-DD HH:MM

### Completed This Session
- What was done, with commit hashes.

### Current State
- Branch: `name`. Last commit: `hash` message.
- Left uncommitted, and why (if anything).
- Verification: what was tested or checked, and how. If the project has no tests, say
  what was checked instead.

### Next Steps
1. The immediate next action, specific enough to start on without rereading the session.

### Open Questions / Blockers
- Anything unresolved.

### Things Worth Not Rediscovering
- Gotchas, dead ends, and facts that took effort to establish, with how they were
  verified.
```

Write for a reader who has not seen this session: put the key points first, make each
item understandable on its own, use plain words, and don't use names you made up during
the work. Say how a claim was verified. Something that only appeared in a tool list, or
was never actually run, is not verified.

**Move lasting facts to where they belong.** A finding that will stay true beyond the
next session belongs in the project's `CLAUDE.md` (if Claude needs it in every session)
or in `docs/` (for reference). Propose the addition to the user, and point to it from the
entry.

## 3. Rotate old entries

If `JOURNAL.md` holds more than three entries, move the older ones to the end of
`JOURNAL_ARCHIVE.md`, keeping them in date order. Create the archive if it doesn't exist,
and keep a link to it near the top of `JOURNAL.md`.

## 4. Commit the journal last

On every branch, commit `JOURNAL.md` (and `JOURNAL_ARCHIVE.md` if it changed) as the
final commit of the session, with the message `Record session handoff`.

## 5. Report

Show a short summary of the entry, list the commits made, and name anything left
uncommitted. Then tell the user the session is ready to end and that `/uadf-start`
resumes it.
