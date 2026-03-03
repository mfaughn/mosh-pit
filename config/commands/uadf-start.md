---
description: Start or resume a UADF session
---

# UADF Session Start

We are operating under the Universal Agentic Development Framework.

Read the framework at @~/.claude/uadf/framework.md if you need to refresh on the protocol.

## Orientation

Read these files and summarize the current state:

1. **`JOURNAL.md`** — Find the most recent session handoff entry
2. **`TASKS.md`** — What tasks are in progress, pending, blocked?
3. **`blueprint.md`** — What's the overall plan?
4. **`CLAUDE.md`** — Project-specific instructions

Also check:
```bash
git status
git log --oneline -10
git branch
```

## Report

After reading, provide a brief status report:

```
## Current State

**Branch:** [current branch]
**Last Session:** [date from most recent handoff]
**Last Completed:** [what was done]

### Active Tasks
- [Task and status]

### Next Steps (from handoff)
1. [Next action]

### Blockers
- [Any blockers or open questions]
```

## Then Ask

"What would you like to work on this session?"

Options I might suggest based on current state:
- Continue with the next task from `TASKS.md`
- Address a blocker
- Start a new feature (will require `/uadf-task`)
- Review and update the blueprint

## Session Rules Reminder

- All work happens on feature branches
- TDD: RED → GREEN → REFACTOR
- Checkpoint commits at each step
- When we hit 20-25 messages, I'll prompt for handoff
- Memory lives in files, not chat
