# UADF Usage Guide

The Universal Agentic Development Framework (UADF) is a structured workflow for AI-assisted development that enforces documentation-first planning, TDD, and explicit version control.

---

## Quick Start

### Starting a New Project

```
/uadf-init my-project-name
```

This will:
1. Interview you about the project (one question at a time)
2. Create all UADF files: `CLAUDE.md`, `spec.md`, `blueprint.md`, `TASKS.md`, `JOURNAL.md`, `ARCHITECTURE.md`
3. Create the first ADR documenting your tech stack
4. Ask you to approve the blueprint before any implementation

### Resuming Work on an Existing UADF Project

```
/uadf-start
```

This will:
1. Read recent handoff from `JOURNAL.md`
2. Check current tasks in `TASKS.md`
3. Review git status
4. Give you a status report and ask what to work on

### Starting a New Task

```
/uadf-task implement user login form
```

This will:
1. Create a task entry in `TASKS.md`
2. Create a feature branch
3. Guide you through TDD: write failing test → implement → refactor
4. Make checkpoint commits at each step

### Ending a Session

```
/uadf-handoff
```

This will:
1. Write a handoff entry to `JOURNAL.md`
2. Update task statuses in `TASKS.md`
3. Commit any work in progress
4. Prepare for the next session to resume

### Creating an Architecture Decision Record

```
/uadf-adr use-postgres-for-database
```

This will:
1. Interview you about the decision
2. Create a numbered ADR in `docs/adr/`
3. Update related documentation

---

## Workflow Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    NEW PROJECT                               │
│  /uadf-init → Interview → spec.md → blueprint.md → APPROVE  │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    EACH SESSION                              │
│  /uadf-start → Status Report → Work → /uadf-handoff         │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    EACH TASK                                 │
│  /uadf-task → Branch → RED → GREEN → REFACTOR → Merge       │
└─────────────────────────────────────────────────────────────┘
```

---

## File Reference

| File | What It Contains |
|------|------------------|
| `CLAUDE.md` | Project-specific instructions (build commands, conventions) |
| `spec.md` | **WHAT** we're building (requirements, acceptance criteria) |
| `blueprint.md` | **HOW** we'll build it (implementation plan, must be approved) |
| `TASKS.md` | Current work items with statuses |
| `JOURNAL.md` | Session handoffs, decisions, blockers |
| `ARCHITECTURE.md` | System design, component structure |
| `docs/adr/` | Architecture Decision Records |

---

## Core Principles

1. **Memory Lives in Files** — Chat history is ephemeral. All important context must be in project files.

2. **Hard Gates** — No implementation code until `blueprint.md` is approved. This prevents wasted work.

3. **TDD is the Path** — Every feature starts with a failing test. The sequence is:
   - RED: Write failing test, commit
   - GREEN: Write minimal code to pass, commit
   - REFACTOR: Clean up, commit

4. **Branch Isolation** — All work on feature branches. Main stays deployable.

5. **Fresh Starts** — New context window every 20-25 messages. Handoff before ending.

---

## Team Mode

By default, UADF uses a single Claude agent for all work. You can enable **team mode** to use specialized agents that work together.

### Enabling Team Mode

```
/uadf-team-on
```

This sets `uadf_team_mode: true` in your project's `CLAUDE.md`.

### Disabling Team Mode

```
/uadf-team-off
```

### How Team Mode Works

| Agent | Role | When Active |
|-------|------|-------------|
| **You** | Team Lead — approve/reject work, make decisions | Always |
| **Dev** | Implements tasks following TDD | During `/uadf-task` |
| **QA** | Reviews Dev's work, suggests improvements | After Dev completes |
| **Architect** | Handles design decisions, drafts ADRs | During `/uadf-adr` |

### Team Mode Workflow

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│     You      │────▶│   Dev Agent  │────▶│   QA Agent   │
│  (approve)   │◀────│ (implement)  │◀────│  (review)    │
└──────────────┘     └──────────────┘     └──────────────┘
```

1. You run `/uadf-task implement login`
2. Dev agent creates branch, writes test (RED), implements (GREEN), refactors
3. QA agent reviews the implementation
4. If QA finds issues, Dev iterates
5. When QA approves, you decide whether to merge

### Verbose Output

Team mode includes verbose logging so you can see what agents are doing:

```
[UADF Team] Task: implement login form
[UADF Team] Spawning Dev agent...
[UADF Dev] Creating branch feature/003-login-form
[UADF Dev] Writing failing test...
[UADF Dev] RED: login validation rejects empty email - committed
[UADF Dev] Implementing login validation...
[UADF Dev] GREEN: login validation passes - committed
[UADF Team] Spawning QA agent...
[UADF QA] Reviewing implementation...
[UADF QA] Result: APPROVED
```

### Token Usage

Team mode uses approximately 2-3x more tokens per task due to multiple agents. This is a trade-off for:
- Specialized focus (Dev on implementation, QA on review)
- Built-in code review
- Educational value (seeing how agents coordinate)

You can switch between modes at any time — no project restructuring needed.

---

## Git Workflow

### Starting Work
```bash
git checkout -b feature/NNN-description
```

### Checkpoint Commits
```bash
git commit -m "RED: user can submit form fails"
git commit -m "GREEN: user can submit form passes"
git commit -m "REFACTOR: extract form validation"
```

### Completing Work
```bash
git checkout main
git merge feature/NNN-description
git branch -d feature/NNN-description
```

### Rolling Back
```bash
# Within branch - go to previous checkpoint
git log --oneline
git reset --hard <commit-hash>

# Abandon branch entirely
git checkout main
git branch -D feature/NNN-description
```

---

## Tips

### When to Use UADF vs. Quick Projects

**Use UADF when:**
- Building something non-trivial
- You'll work on it across multiple sessions
- Quality and stability matter
- You want to avoid "what was I doing?" confusion

**Use `/newproject` (simpler workflow) when:**
- Quick prototype or experiment
- Single-session project
- Learning/exploring a technology

### Keeping Sessions Productive

- Start every session with `/uadf-start` — it orients you
- Use checkpoint commits liberally — they're your undo points
- Write handoffs even for short sessions — future you will thank you
- Don't skip the RED step — catching bugs is harder than preventing them

### When TDD Doesn't Fit

For config changes, documentation, or styling:
- Still use feature branches
- Still make checkpoint commits
- Just skip the RED/GREEN pattern
- Use `/uadf-task` — it handles non-TDD tasks too

---

## Troubleshooting

### "I forgot to handoff last session"

Run `/uadf-start`. It will check git history and TASKS.md to reconstruct state. The information might be less detailed, but you can continue.

### "Tests are failing and I don't know why"

Check `git log --oneline`. Find your last GREEN commit. `git diff <green-commit>` shows what changed since tests passed.

### "I'm stuck on a task"

Update TASKS.md to mark it BLOCKED with a note explaining why. Create a new task to investigate the blocker, or use `/uadf-adr` if it requires an architectural decision.

### "The blueprint needs to change mid-project"

Update `blueprint.md`, add a note to `JOURNAL.md` explaining why, and create an ADR if it's a significant architectural change.

---

## Command Reference

| Command | Description |
|---------|-------------|
| `/uadf-init [name]` | Initialize a new UADF project |
| `/uadf-start` | Start or resume a session |
| `/uadf-task [desc]` | Start a task with TDD lifecycle |
| `/uadf-handoff` | Write session handoff to JOURNAL.md |
| `/uadf-adr [title]` | Create an Architecture Decision Record |
| `/uadf-team-on` | Enable agent team mode |
| `/uadf-team-off` | Disable agent team mode |
| `/uadf-help` | Show quick reference help |

---

## Installation Location

```
~/.claude/
├── CLAUDE.md                    # Global preferences (UADF section added)
├── uadf/
│   ├── README.md                # This file
│   ├── framework.md             # Canonical UADF reference
│   └── templates/
│       ├── JOURNAL.md
│       ├── TASKS.md
│       ├── spec.md
│       ├── blueprint.md
│       ├── ARCHITECTURE.md
│       └── adr-template.md
└── commands/
    ├── uadf-init.md
    ├── uadf-start.md
    ├── uadf-task.md
    ├── uadf-handoff.md
    ├── uadf-adr.md
    ├── uadf-team-on.md
    ├── uadf-team-off.md
    └── uadf-help.md
```
