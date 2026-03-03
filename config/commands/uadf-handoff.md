---
description: Write session handoff to JOURNAL.md
---

# UADF Session Handoff

We're ending this session or approaching the 20-25 message limit. Time to write a handoff entry.

## Gather Information

Check the current state:
```bash
git status
git log --oneline -10
git branch
```

Review what we accomplished this session (scan recent conversation).

## Write Handoff Entry

Append the following to `JOURNAL.md`:

```markdown
## Session Handoff - [TODAY'S DATE] [CURRENT TIME]

### Completed This Session
- [List what was accomplished]
- [Include any commits made]

### Current State
- Branch: `[current branch name]`
- Last checkpoint: `[most recent commit message]`
- Tests: [All passing / N failing / Not run]

### Next Steps
1. [Immediate next action - be specific]
2. [Following action]
3. [Further actions if known]

### Open Questions / Blockers
- [Anything unresolved that the next session needs to address]
- [Decisions that need to be made]

### Relevant Context
- [Anything the next session needs to know that isn't obvious from the files]
- [Gotchas discovered, things tried that didn't work, etc.]
```

## Update TASKS.md

Ensure task statuses are current:
- Mark completed tasks as `COMPLETED`
- Update `IN_PROGRESS` tasks with current state
- Add any new tasks discovered during the session

## Final Commit

If there are uncommitted changes:
```bash
git add -A
git commit -m "WIP: session handoff - [brief description]"
```

## Confirm

After writing the handoff:
- Show me the handoff entry
- Confirm what's committed
- Let me know the session is ready to end

"Handoff complete. You can safely end this session. Run `/uadf-start` in your next session to resume."
