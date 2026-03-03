# Universal Agentic Development Framework (UADF)
**Version:** 2.1.0

## 1. Overview

The UADF is a meta-workflow that converts AI coding agents into a disciplined engineering process. It enforces documentation-first development, TDD, and explicit version control protocols.

**Primary Use Case:** Solo developer working with AI assistants on web applications.

---

## 2. Core Principles

| # | Principle | Rationale |
|---|-----------|-----------|
| 1 | **Memory Lives in Files** | All context lives in project files, never in chat history. Chat is ephemeral; files are permanent. |
| 2 | **Fresh Starts** | Start a new context window every 20-25 messages. Write a handoff entry in `JOURNAL.md` before ending. |
| 3 | **Hard Gates** | No implementation code until `blueprint.md` is approved. No task marked complete without passing tests. |
| 4 | **TDD is the Path** | Every feature begins with a failing test. TDD is embedded in the task lifecycle. |
| 5 | **Branch Isolation** | All implementation work happens on feature branches. Main branch stays deployable. |

---

## 3. Project File Structure

| File | Purpose | Updated By |
|------|---------|------------|
| `CLAUDE.md` | Project instructions: build, test, lint commands, conventions | Human (occasionally Agent) |
| `spec.md` | **WHAT**: Product requirements, user stories, acceptance criteria | Human via Socratic interview |
| `blueprint.md` | **HOW**: Step-by-step implementation plan, file changes | Architect Agent (human approves) |
| `TASKS.md` | **WORK**: Atomic tasks derived from blueprint | Lead Agent |
| `JOURNAL.md` | **LOG**: Session handoffs, blockers, decisions, learnings | Human and Agents |
| `ARCHITECTURE.md` | High-level system design, component relationships | Architect Agent |
| `docs/adr/` | **WHY**: Architecture Decision Records | Human and Agents |

---

## 4. Task Lifecycle (TDD-Embedded)

States: `PENDING` → `IN_PROGRESS` → `COMPLETED` (also: `BLOCKED`, `CANCELLED`, `DEFERRED`)

### PENDING → IN_PROGRESS

1. Create feature branch: `git checkout -b feature/<task-id>-<description>`
2. Write failing test first
3. Commit: `git commit -m "RED: <test description> fails"`

### IN_PROGRESS: Implementation

1. Write minimal code to pass the test
2. Commit: `git commit -m "GREEN: <test description> passes"`
3. Refactor if needed, commit: `git commit -m "REFACTOR: <what changed>"`

### IN_PROGRESS → COMPLETED

- RED commit exists
- GREEN commit exists
- All tests pass
- Branch merged or ready to merge
- JOURNAL.md updated if notable decisions made

### Definition of Done by Task Type

| Task Type | Requirements |
|-----------|--------------|
| **Feature** | Tests pass, UI verified manually, branch merged |
| **Bug Fix** | Regression test added, fix verified, branch merged |
| **Refactor** | All existing tests pass, no behavior change |
| **Documentation** | Reviewed for accuracy, links work |
| **Spike/Research** | Findings documented in JOURNAL.md, ADR if architectural |

---

## 5. Version Control Protocol

### Primary: Branch Isolation + Checkpoints

```bash
# Start
git checkout -b feature/<task-id>-<description>

# Checkpoints
git commit -m "RED: ..."
git commit -m "GREEN: ..."
git commit -m "REFACTOR: ..."

# Complete
git checkout main
git merge feature/<task-id>-<description>
git branch -d feature/<task-id>-<description>
```

### Rollback

```bash
# Within branch
git log --oneline
git reset --hard <commit-hash>

# Abandon branch
git checkout main
git branch -D feature/<task-id>-<description>
```

### Secondary: Git Stash (Quick Experiments Only)

```bash
git stash push -m "experiment: trying alternative"
git stash pop   # if it works
git stash drop  # if it doesn't
```

### DO NOT USE

- `git reset --hard` on main
- `git push --force` on shared branches
- Working directly on main

---

## 6. Session Handoff

When approaching 20-25 messages or ending a session, write to JOURNAL.md:

```markdown
## Session Handoff - [DATE] [TIME]

### Completed This Session
- [What was accomplished]

### Current State
- Branch: `feature/xxx`
- Last checkpoint: `GREEN: xxx passes`
- Tests: All passing / N failing

### Next Steps
1. [Immediate next action]
2. [Following action]

### Open Questions / Blockers
- [Anything unresolved]
```

### Starting a New Session

1. Read `JOURNAL.md` (most recent handoff)
2. Read `TASKS.md` (current states)
3. Read `blueprint.md` (overall plan)
4. Check `git status` and `git log --oneline -10`
5. Resume work

---

## 7. When TDD Doesn't Fit

| Task Type | Approach |
|-----------|----------|
| **Config changes** | Make change, verify app works, checkpoint commit |
| **Documentation** | Write/update, checkpoint commit |
| **Exploratory spike** | Branch, experiment, document in JOURNAL.md, may discard |
| **UI/Styling** | Visual test if possible, otherwise manual + screenshot |
| **Dependency updates** | Run existing tests, verify no regressions, checkpoint |

---

## 8. Web Application Defaults

```bash
npm test              # Unit/Integration
npm run test:e2e      # E2E
npm run typecheck     # Type checking
npm run lint          # Linting
```

Override in project's `CLAUDE.md`.

---

## 9. Team Mode

UADF supports two execution modes:

### Single Agent Mode (Default)

One Claude agent handles all work. Simpler, lower token usage, easier to debug.

**To use:** This is the default. No action needed.

### Team Mode

Specialized agents work together:

| Agent | Role |
|-------|------|
| **You** | Team Lead — approve/reject, make decisions |
| **Dev** | Implements tasks following TDD |
| **QA** | Reviews implementations, suggests improvements |
| **Architect** | Handles design decisions, drafts ADRs |

**To enable:** Run `/uadf-team-on` or set `uadf_team_mode: true` in project's `CLAUDE.md`

**To disable:** Run `/uadf-team-off` or set `uadf_team_mode: false`

### Team Mode Workflow

```
/uadf-task "implement login"
    │
    ▼
[Dev Agent] Branch → RED → GREEN → REFACTOR
    │
    ▼
[QA Agent] Review → APPROVED / NEEDS CHANGES
    │
    ▼ (if needs changes, iterate)
[You] Approve merge
```

### Token Usage

| Mode | Approximate Usage |
|------|-------------------|
| Single Agent | 1x (baseline) |
| Team Mode | 2-3x per task |

Team mode is optional. Switch between modes at any time — project files are the same either way.

---

## 10. UADF Skills Reference

| Skill | Purpose |
|-------|---------|
| `/uadf-init` | Initialize project with UADF files |
| `/uadf-start` | Begin/resume a session |
| `/uadf-task` | Start a new task with TDD lifecycle |
| `/uadf-handoff` | Write session handoff to JOURNAL.md |
| `/uadf-adr` | Create a new Architecture Decision Record |
| `/uadf-team-on` | Enable agent team mode |
| `/uadf-team-off` | Disable agent team mode |
| `/uadf-help` | Show quick reference help |
