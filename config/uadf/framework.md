# Universal Agentic Development Framework (UADF)
**Version:** 4.0.0

UADF adds two things to Claude Code:

1. **Session continuity.** `JOURNAL.md` records what happened and what's next, so a new
   session can pick up where the last one stopped. It lives in git, so it survives
   `mosh fresh`, other machines and lost session history. Claude Code's auto memory
   survives none of those.
2. **Decision records.** ADRs in `docs/adr/` record why significant choices were made.

Everything else (planning, review, commits, subagents) is left to Claude Code's built-in
tools and plugins.

## Files

| File | Purpose |
|---|---|
| `JOURNAL.md` | The latest session handoffs and notes, newest at the bottom |
| `JOURNAL_ARCHIVE.md` | Older entries, read only when needed |
| `docs/adr/NNNN-title.md` | Architecture Decision Records |

Lasting facts don't belong in the journal. Put what Claude needs in every session in the
project's `CLAUDE.md`, and put reference material in `docs/`. The journal is for what
changes from session to session.

## Skills

| Skill | Does |
|---|---|
| `/uadf-init [name]` | Creates `JOURNAL.md` and `docs/adr/` |
| `/uadf-start` | Reads the newest journal entry, checks it against git, reports, asks what's next |
| `/uadf-handoff` | Commits the session's work, writes the handoff, rotates old entries, commits the journal last |
| `/uadf-adr [title]` | Writes an ADR, drafting from the session's discussion |

All four run only when you type them (`disable-model-invocation: true`).

## Handoff commit rules

- On `main`, review with the user what should and shouldn't be committed before writing
  the entry.
- On other branches, Claude commits the work, choosing between one commit and several,
  and asks when unsure.
- Never commit secrets, generated output or stray untracked files without asking.
- The journal entry is always the last commit of the session, on every branch.

## When to write an ADR

For a choice with real trade-offs: technology selection, data model or API design,
infrastructure or deployment approach.

## Layout and installation

The source lives in the mosh-pit repo at `config/uadf/`:

```
config/uadf/
├── framework.md        this file
├── skills/uadf-*/      the four skills
├── templates/          JOURNAL.md, adr-template.md
├── install-host.sh     links the skills into ~/.claude on the host
├── CHANGELOG.md
└── LICENSE
```

- **In mosh containers,** `launch.sh` copies `config/uadf/` to `~/.claude/uadf/` and the
  skills to `~/.claude/skills/` on every launch.
- **On the host,** run `config/uadf/install-host.sh` once. It symlinks the skills and this
  directory into `~/.claude`, so edits in the repo take effect immediately.
