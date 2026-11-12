---
name: uadf-init
description: Set up a project for UADF by creating JOURNAL.md and docs/adr/.
argument-hint: "[project name]"
disable-model-invocation: true
---

# Set up UADF: $ARGUMENTS

This is setup only. Don't write implementation code.

1. **Check what exists.**
   - If `JOURNAL.md` already exists, the project may already use UADF. Ask whether to
     resume with `/uadf-start`, or what to do with the existing file. Stop until the user
     answers.
   - If git has uncommitted changes, tell the user and ask whether to continue.

2. **Create the files.**
   - Run `git init` if this isn't a git repository yet.
   - Create `docs/adr/`.
   - Create `JOURNAL.md` from `~/.claude/uadf/templates/JOURNAL.md`, filling in the
     project name, today's date and the project's goal. Ask the user for the goal if it
     isn't clear.

3. **CLAUDE.md.** If the project has none, suggest running `/init` to generate one. Don't
   add a UADF section to it; the skills carry the protocol.

4. **Commit** the new files: `Set up UADF`.

5. **Report** what was created, and mention `/uadf-start`, `/uadf-handoff` and
   `/uadf-adr`.
