# Changelog

All notable changes to UADF. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and versions follow
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [4.0.0] - 2026-11-12

Moved into the mosh-pit repo (`config/uadf/`) from `github.com/mfaughn/UADF`. Rewritten
after reviewing Anthropic's Fable 5.2 and Claude Code guidance against eight months of
actual use.

### Changed
- Commands are now skills (`skills/<name>/SKILL.md`) with `disable-model-invocation: true`,
  so they run only when you type them.
- `/uadf-start` reads only the newest journal entry and checks it against git.
- `/uadf-handoff` commits the session's work first (on `main`, it reviews what to commit
  with you), then commits the journal as the last step on every branch. It no longer runs
  `git add -A`.
- Handoffs have a "Things Worth Not Rediscovering" section, ask for how each claim was
  verified, and move lasting facts into `CLAUDE.md` or `docs/`.
- Old entries rotate to `JOURNAL_ARCHIVE.md`.
- `/uadf-adr` drafts from the session's discussion instead of always interviewing.

### Removed
- `/uadf-help`. The `/` menu lists the skills, and `framework.md` covers the rest.
- References to the `feature-dev` plugin, which was never installed.

## [3.0.0] - 2026-03-06

### Changed
- Reduced UADF to session continuity (JOURNAL.md) and decision tracking (ADRs). Feature
  planning, TDD, review and agent teams were left to Claude Code's built-in tools.

### Removed
- `/uadf-task`, `/uadf-team-on`, `/uadf-team-off`, `spec.md`, `blueprint.md`, `TASKS.md`,
  `ARCHITECTURE.md` templates.

## [2.1.0] - 2026-02-17

### Added
- **Team Mode**: Optional multi-agent workflow with Dev and QA agents
  - `/uadf-team-on` to enable specialized agents
  - `/uadf-team-off` to return to single agent mode
  - Verbose logging shows agent coordination
- **Help Command**: `/uadf-help` for quick reference
- **Pre-flight Checks**: `/uadf-init` now checks for conflicts before proceeding
  - Detects existing UADF files
  - Warns about uncommitted git changes
  - Checks for CLAUDE.md conflicts
- **Install Script**: `install.sh` for easy setup on macOS/Linux

### Changed
- `/uadf-task` now checks for team mode and spawns agents accordingly
- Updated all documentation with team mode instructions
- Improved README with clearer installation instructions

## [2.0.0] - 2026-02-17

### Added
- Architecture Decision Records (ADRs) in `docs/adr/`
- `/uadf-adr` command to create ADRs
- Session handoff protocol with explicit template
- Definition of Done by task type
- Explicit rollback procedures (branch isolation + checkpoints)
- Git stash as secondary rollback method
- "Methods NOT to use" documentation

### Changed
- Clarified file purposes: spec.md (WHAT), blueprint.md (HOW), TASKS.md (WORK), JOURNAL.md (LOG)
- TDD is now embedded in task lifecycle, not a verification step
- Task states expanded: added CANCELLED, DEFERRED
- Version control protocol formalized

### Removed
- Vague "rollback" instruction replaced with explicit procedures

## [1.0.0] - 2026-02-17

### Added
- Initial framework based on Dylan Davis "Boring Rules"
- Core principles: Memory First, Fresh Starts, Hard Gates, TDD Enforcement
- Project file structure: CLAUDE.md, JOURNAL.md, ARCHITECTURE.md, spec.md, blueprint.md, TASKS.md
- Master Orchestration Prompt
- Integration of Claude Conductor document templates
- Integration of Superpowers agentic patterns
