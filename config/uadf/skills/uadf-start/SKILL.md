---
name: uadf-start
description: Resume work on a UADF project. Reads the latest JOURNAL.md entry, checks it against git, and reports where things stand.
disable-model-invocation: true
---

# Start a UADF session

If the project has no `JOURNAL.md`, say so and suggest `/uadf-init`. Stop there.

1. **Read the newest journal entry.** Entries are `## ` headings in `JOURNAL.md`, with the
   newest at the bottom. Read that whole entry, not the whole file. The latest entry may be
   a handoff or another kind of note; treat it the same way. Open `JOURNAL_ARCHIVE.md` only
   if the entry points to older history you need.

2. **Check the entry against git.** Run `git status`, `git log --oneline -10` and
   `git branch`. Look for anything that changed since the entry was written: commits made
   after it, branches merged or deleted, next steps that are already done. The journal is
   often a step behind git, and this check is the most useful part of the report.

3. **Report**, briefly:
   - Branch and working-tree state.
   - Date and one- or two-line summary of the last session.
   - Open next steps from the entry, marking any that git shows are already done.
   - Blockers and open questions.
   - Anything in the entry that git contradicts.

4. **Ask what to work on.** Suggest options: continue the next step, address a blocker,
   or start something new.
