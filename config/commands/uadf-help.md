---
description: Get help with UADF commands and workflow
---

# UADF Help

The Universal Agentic Development Framework (UADF) is a structured workflow for AI-assisted development.

---

## Quick Reference

| Command | What It Does |
|---------|--------------|
| `/uadf-init [name]` | Initialize a new UADF project |
| `/uadf-start` | Start or resume a session |
| `/uadf-task [desc]` | Start a task with TDD lifecycle |
| `/uadf-handoff` | Write session handoff to JOURNAL.md |
| `/uadf-adr [title]` | Create an Architecture Decision Record |
| `/uadf-team-on` | Enable agent team mode |
| `/uadf-team-off` | Disable agent team mode |
| `/uadf-help` | Show this help |

---

## Getting Started

### New Project
```
/uadf-init my-project-name
```
This interviews you, creates planning documents, and asks for blueprint approval before any code is written.

### Existing UADF Project
```
/uadf-start
```
This reads your last session handoff and gets you oriented.

---

## Core Workflow

```
1. /uadf-init        → Interview → spec.md → blueprint.md → APPROVE
2. /uadf-start       → Orient → Work on tasks
3. /uadf-task        → Branch → RED → GREEN → REFACTOR → Merge
4. /uadf-handoff     → Write handoff → End session
5. (repeat 2-4)
```

---

## Project Files

| File | Purpose |
|------|---------|
| `CLAUDE.md` | Project instructions, build commands |
| `spec.md` | WHAT we're building (requirements) |
| `blueprint.md` | HOW we'll build it (must be approved) |
| `TASKS.md` | Current work items |
| `JOURNAL.md` | Session handoffs, decisions |
| `ARCHITECTURE.md` | System design |
| `docs/adr/` | Architecture Decision Records |

---

## Team Mode

By default, UADF uses a single agent (Claude). You can enable team mode for specialized agents:

```
/uadf-team-on     # Enable team mode
/uadf-team-off    # Disable team mode
```

**In team mode:**
- Dev agent implements tasks
- QA agent reviews implementations
- Architect agent handles design decisions

Team mode uses more tokens but can improve quality through specialization and review.

---

## Key Principles

1. **Memory in Files** — Everything important goes in project files, not chat
2. **Hard Gates** — No code until blueprint is approved
3. **TDD** — Every feature starts with a failing test
4. **Branch Isolation** — All work on feature branches
5. **Fresh Starts** — New session every 20-25 messages, handoff before ending

---

## Common Questions

**Q: How do I continue after a break?**
A: Run `/uadf-start` — it reads your handoff and orients you.

**Q: What if I forgot to handoff?**
A: `/uadf-start` will check git history and TASKS.md to reconstruct state.

**Q: Can I skip TDD for some tasks?**
A: Yes. Config changes, docs, and styling don't need RED/GREEN. Still use branches and commits.

**Q: How do I change the blueprint mid-project?**
A: Update `blueprint.md`, add a note to `JOURNAL.md`, create an ADR if it's architectural.

---

## More Information

Full documentation: `~/.claude/uadf/README.md`
Framework reference: `~/.claude/uadf/framework.md`
