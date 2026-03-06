# Universal Agentic Development Framework (UADF)
**Version:** 3.0.0

## 1. Philosophy

UADF adds two things to Claude Code's built-in capabilities:

1. **Session continuity** — JOURNAL.md captures what happened and what's next, so a new session can resume where the last one left off.
2. **Decision tracking** — Architecture Decision Records (ADRs) document why significant choices were made.

Everything else — feature planning, TDD, code review, commits, agent teams — is handled by Claude Code natively or via official plugins.

### Core Principles

| Principle | Meaning |
|-----------|---------|
| **Memory in files** | Important context goes in project files (JOURNAL.md, CLAUDE.md, ADRs), not chat history. Chat is ephemeral. |
| **Session handoffs** | Before ending a session, write a handoff to JOURNAL.md so the next session can pick up seamlessly. |
| **Branch discipline** | Work on feature branches. Keep main deployable. |
| **Decisions as records** | When a significant architectural choice is made, capture it in an ADR. |

---

## 2. Project Files

UADF adds two files to a project:

| File | Purpose |
|------|---------|
| `JOURNAL.md` | Session handoffs, notable decisions, project log |
| `docs/adr/` | Architecture Decision Records |

These complement the standard `CLAUDE.md` that every Claude Code project uses.

---

## 3. Session Protocol

### Starting a Session

1. Read `JOURNAL.md` — find the most recent handoff
2. Read `CLAUDE.md` — project instructions and conventions
3. Check `git status` and `git log --oneline -10`
4. Report current state and ask what to work on

Use `/uadf-start` to do this automatically.

### During a Session

- Work normally using Claude Code's tools and plugins
- Use feature branches for implementation work
- Write important decisions and context to files as you go

### Ending a Session

Append a handoff entry to `JOURNAL.md`:

```markdown
## Session Handoff - [DATE] [TIME]

### Completed This Session
- [What was accomplished, commits made]

### Current State
- Branch: `[branch name]`
- Last checkpoint: `[recent commit]`
- Tests: [status]

### Next Steps
1. [Immediate next action]
2. [Following actions]

### Open Questions / Blockers
- [Anything unresolved]
```

Use `/uadf-handoff` to do this automatically.

---

## 4. Architecture Decision Records

Create an ADR when making a significant choice about:
- Technology or framework selection
- Data model or API design
- Infrastructure or deployment approach
- Any decision with meaningful trade-offs

ADRs live in `docs/adr/` as numbered markdown files. Use `/uadf-adr` to create one.

---

## 5. Complementary Tools

UADF works alongside these Claude Code capabilities:

| Need | Tool |
|------|------|
| Feature planning & implementation | `/feature-dev` plugin |
| Code review | `/code-review` plugin |
| Git commits & PRs | `/commit` skill, `gh` CLI |
| Parallel work | Agent teams (native) |
| Task planning | Plan mode (native) |

---

## 6. Commands Reference

| Command | Purpose |
|---------|---------|
| `/uadf-init [name]` | Initialize project with JOURNAL.md and docs/adr/ |
| `/uadf-start` | Start or resume a session |
| `/uadf-handoff` | Write session handoff to JOURNAL.md |
| `/uadf-adr [title]` | Create an Architecture Decision Record |
| `/uadf-help` | Show quick reference |
