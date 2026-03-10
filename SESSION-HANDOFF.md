# Session Handoff — 2026-03-10

See `NOTES.md` for architecture decisions and investigation history.

## Open Items

1. **OAuth re-auth per project**: Each project gets its own named volume, so credentials don't carry between projects. Could share a credentials volume or copy `.credentials.json` between them.
2. **UADF command naming**: `/uadf:uadf-init` is redundant. Options: rename files to drop `uadf-` prefix (→ `/uadf:init`) or move back to root commands dir. User is deciding.
3. **Vitest orphan workers**: Fix (`pool: "forks"` + `singleFork: true`) applied to ezfhir only. Other projects using vitest in containers may need the same. Consider documenting in NOTES.md or adding to a project template.
