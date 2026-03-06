# Session Handoff — 2026-03-06

## What This Session Accomplished

### mosh-pit repo changes (committed and pushed):
1. Container persistence — containers survive restarts, named `cc-<project>`
2. `save`/`restore`/`snapshots`/`fresh` commands for container lifecycle
3. Dual auth support (Vertex AI + Anthropic API key + OAuth)
4. tini as PID 1 to prevent zombie process accumulation
5. Shared `~/.claude/commands/` via bind mount (no more manual syncing)
6. Per-project provisioning (`.claude-dev/provision.sh` maintained by Claude Code)
7. Default plugin installation on new containers (`config/default-plugins.txt`)
8. Per-project plugin tracking (`.claude-dev/plugins.txt`)
9. `GITHUB_PERSONAL_ACCESS_TOKEN` moved to `.env` (gitignored), removed from `settings.json`
10. Plugins bind mount changed to read-write (was read-only, caused marketplace clone failure)

### NOT yet committed/pushed:
- Plugin bind mount was removed (replaced by plugin install list approach) — in local `claude-dev.sh` but not committed
- `config/default-plugins.txt` created but not committed
- `install_plugins()` function added to `claude-dev.sh` but not committed
- CLAUDE.md updated with plugin tracking instruction but not committed

### Changes to host `~/.claude/`:
- `settings.json` — `GITHUB_PERSONAL_ACCESS_TOKEN` re-added (user put it back)
- `commands/` — user moved `newfeature.md`, `endfeature.md`, `newproject.md`, `updateclaudemd.md` to `commands_old/`
- `commands/` — user organized UADF commands into `uadf/` subdirectory

## Pending: UADF Slim-Down

A comprehensive plan exists at `~/.claude/plans/floofy-cuddling-puzzle.md`.

### Summary of the plan:

**Goal:** Trim UADF to only augment Claude Code's official capabilities, not replace them.

**Keep (with refinements):**
- `/uadf-start` — session resume via JOURNAL.md (simplify, remove TASKS.md/blueprint.md refs)
- `/uadf-handoff` — session handoff to JOURNAL.md (simplify, remove rigid message limit)
- `/uadf-adr` — Architecture Decision Records (minor tweaks)
- `/uadf-init` — major rewrite: only creates JOURNAL.md + docs/adr/ (no more spec.md, blueprint.md, TASKS.md, ARCHITECTURE.md)
- `/uadf-help` — rewrite to match slimmed framework

**Delete:**
- `/uadf-task` — replaced by `feature-dev` plugin
- `/uadf-team-on` — replaced by native agent teams
- `/uadf-team-off` — no longer needed
- Templates: `TASKS.md`, `spec.md`, `blueprint.md`, `ARCHITECTURE.md`
- Keep templates: `JOURNAL.md`, `adr-template.md`

**Rewrite:**
- `config/uadf/framework.md` — slim from 242 to ~80 lines (philosophy + session protocol only)
- `config/CLAUDE.md` — update UADF section
- `~/.claude/CLAUDE.md` — same update

**Edit location:** All command edits in `~/.claude/commands/` (host). Delete all files from `config/commands/` (they're stale duplicates).

## Current State

- **Repo:** https://github.com/mfaughn/mosh-pit (private)
- **Branch:** main
- **Local uncommitted changes:** Yes (plugin install list, CLAUDE.md update, claude-dev.sh changes)
- **Host commands dir:** `~/.claude/commands/` with `uadf/` subdirectory containing all uadf commands
- **Plugins installed (host):** playwright, code-review, code-simplifier, ralph-loop, commit-commands, frontend-design, github

## Next Steps (in order)

1. **Commit and push** the pending local changes to mosh-pit (plugin list, install_plugins function, CLAUDE.md updates)
2. **Execute the UADF slim-down plan** per `~/.claude/plans/floofy-cuddling-puzzle.md`:
   - Delete obsolete commands from `~/.claude/commands/uadf/`
   - Delete all files from `config/commands/`
   - Rewrite remaining commands in `~/.claude/commands/uadf/`
   - Rewrite `config/uadf/framework.md`
   - Delete obsolete templates from `config/uadf/templates/`
   - Update CLAUDE.md (both host and container versions)
3. **Commit and push** the UADF changes
4. **Test** in a fresh container to verify skills list is correct

## Key Files

| File | Path | Notes |
|------|------|-------|
| Launch script | `/Users/mrf/projects/safeClaude/claude-dev.sh` | Has uncommitted plugin changes |
| Container config | `/Users/mrf/projects/safeClaude/config/` | Repo copy, mounted into containers |
| Host commands | `~/.claude/commands/` | Source of truth, bind-mounted |
| Host CLAUDE.md | `~/.claude/CLAUDE.md` | Needs UADF section update |
| Container CLAUDE.md | `/Users/mrf/projects/safeClaude/config/CLAUDE.md` | Needs same update |
| Framework | `/Users/mrf/projects/safeClaude/config/uadf/framework.md` | Needs major rewrite |
| UADF templates | `/Users/mrf/projects/safeClaude/config/uadf/templates/` | Delete 4, keep 2 |
| Plan file | `~/.claude/plans/floofy-cuddling-puzzle.md` | Full plan details |
| Default plugins | `/Users/mrf/projects/safeClaude/config/default-plugins.txt` | Not yet committed |
