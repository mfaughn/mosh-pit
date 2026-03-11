# Session Handoff — 2026-03-11

See `NOTES.md` for architecture decisions and investigation history.

## What happened this session

1. **Diagnosed idle session hang**: Claude Code in a container left idle ~3 days became unresponsive. Traced through `/proc` diagnostics — not zombies (tini working), not network (no TCP connections). Process blocked in FUSE `request_wait_answer`, likely due to Podman VM sleep/wake on macOS. Documented in NOTES.md.

2. **Found shared bind mount cross-contamination**: Old containers (`cc-ezfhir`, `cc-drivetrain`, `cc-v2ig`) all bind-mounted `safeClaude/config` as `~/.claude/`, sharing session state across projects. All session data collided at `~/.claude/projects/-workspace/`. Fix: `mosh fresh` to recreate with named volumes.

3. **Added container version tracking**: `MOSH_VERSION` / `MOSH_MIN_COMPAT` scheme with labels stamped on containers at creation. Resume path checks version — warns on outdated, blocks on incompatible.

4. **Fixed container naming**: Was derived from `$(pwd)`, now derived from project arguments. Extracted `container_name_from_dirs()` shared function. Names are sorted so argument order doesn't matter (`mosh A B` == `mosh B A`). Added mount mismatch detection on resume.

5. **Cleaned up safeClaude → mosh-pit migration**: Updated SETUP-GUIDE.md references, removed redundant old notes. Host symlink and PATH entry updated to point to mosh-pit.

6. **Provision script stale-cwd guard**: Added (by another Claude instance) a DEBUG trap to protect against deleted temp directories during provisioning.

## Open Items

1. **OAuth re-auth per project**: Each project gets its own named volume, so credentials don't carry between projects. Could share a credentials volume or copy `.credentials.json` between them.
2. **UADF command naming**: `/uadf:uadf-init` is redundant. Options: rename files to drop `uadf-` prefix (→ `/uadf:init`) or move back to root commands dir.
3. **Vitest orphan workers**: Fix (`pool: "forks"` + `singleFork: true`) applied to ezfhir only. Other projects may need it.
4. **Delete safeClaude directory**: Can't rename while cc-mosh-pit has a bind mount to `safeClaude/config`. After `mosh fresh` for mosh-pit, the directory can be removed.
5. **HANDOFF.md**: Obsolete (from original Feb 24 planning conversation). Can be deleted.
