---
description: Disable agent team mode, return to single agent
---

# Disable UADF Team Mode

Disabling agent team mode. The project will return to single-agent operation where Claude handles all tasks directly.

---

## What Changes

| Command | Team Mode (current) | Single Agent (after) |
|---------|---------------------|----------------------|
| `/uadf-task` | Dev + QA agents | Claude implements directly |
| `/uadf-adr` | Architect agent | Claude writes ADR |
| All work | Specialized agents | Single Claude agent |

**Benefits of single agent mode:**
- Lower token usage (~1/2 to 1/3 of team mode)
- Simpler debugging (one agent, one context)
- Faster for small tasks

**Trade-offs:**
- No automatic QA review
- No specialization

---

## Disable Team Mode

### Step 1: Update CLAUDE.md

Change this line in the project's `CLAUDE.md`:

```markdown
## UADF Settings
uadf_team_mode: false
```

Or remove the `uadf_team_mode` line entirely (defaults to false).

### Step 2: Confirm

After updating, confirm:

```
Team mode is now DISABLED for this project.

All UADF commands will use single-agent mode.
- /uadf-task → Claude implements directly
- /uadf-adr → Claude writes ADR

To re-enable team mode later, run /uadf-team-on.
```

---

## Note

Any agents currently running will complete their current task, but no new agents will be spawned for subsequent commands.

Your project files, git branches, and all progress are unaffected — only the execution model changes.
