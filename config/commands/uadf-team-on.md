---
description: Enable agent team mode for the current UADF project
---

# Enable UADF Team Mode

Enabling agent team mode for this project. In team mode, specialized agents handle different aspects of development:

| Agent | Role |
|-------|------|
| **Dev** | Implements tasks following TDD, writes code |
| **QA** | Reviews implementations, suggests improvements, writes additional tests |
| **Architect** | Handles design decisions, drafts ADRs, updates ARCHITECTURE.md |

---

## What Changes

When team mode is enabled:

| Command | Single Agent | Team Mode |
|---------|--------------|-----------|
| `/uadf-task` | Claude implements directly | Dev agent implements, QA agent reviews |
| `/uadf-adr` | Claude writes ADR | Architect agent drafts ADR |
| Blueprint changes | Claude updates | Architect agent proposes, you approve |

You remain the **Team Lead** — agents report to you, and you approve their work.

---

## Enable Team Mode

### Step 1: Update CLAUDE.md

Add or update this line in the project's `CLAUDE.md`:

```markdown
## UADF Settings
uadf_team_mode: true
```

### Step 2: Confirm

After updating, confirm:

```
Team mode is now ENABLED for this project.

When you run /uadf-task, I will:
1. Spawn a Dev agent to implement the task
2. Dev agent follows TDD (RED → GREEN → REFACTOR)
3. Spawn a QA agent to review the implementation
4. QA sends feedback to Dev for iteration
5. Final result comes to you for approval

[UADF Team] Verbose mode is ON — you'll see what agents are doing.

To disable team mode later, run /uadf-team-off.
```

---

## Team Communication (Verbose Mode)

With team mode enabled, you'll see agent activity:

```
[UADF Team] Spawning Dev agent for TASK-003: implement login form
[UADF Dev] Creating branch feature/003-login-form
[UADF Dev] Writing failing test for login validation...
[UADF Dev] RED: login validation rejects empty email - committed
[UADF Dev] Implementing login validation...
[UADF Dev] GREEN: login validation passes - committed
[UADF Team] Spawning QA agent to review Dev's work
[UADF QA] Reviewing implementation...
[UADF QA] Found 1 suggestion: add test for password length
[UADF QA] Sending feedback to Dev agent
[UADF Dev] Adding password length test...
[UADF Dev] Implementation complete, ready for your review
```

This helps you learn how agents coordinate and catch any issues early.

---

## Token Usage Note

Team mode uses approximately 2-3x more tokens per task because multiple agents are working. Given your budget (~$250/month unused headroom), this should be fine for normal development. You can always `/uadf-team-off` if you want to conserve tokens.

---

## Proceed

Read the project's `CLAUDE.md` and add `uadf_team_mode: true` to enable team mode.

Then confirm: "Team mode enabled. Ready to work with your agent team."
