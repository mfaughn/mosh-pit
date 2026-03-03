# File: ~/.claude/commands/updateclaude.md

---
description: Review recent work and consolidate important context into CLAUDE.md
---

# Context Consolidation

Review the following for any important updates that should be captured in `CLAUDE.md`:

1. **`decisions.md`** — Any decisions not yet reflected in CLAUDE.md?
2. **Recent commits** — !`git log --oneline -10`
3. **Current file structure** — Has it evolved beyond what's documented?
4. **`tasks.md`** — Any completed work that established new patterns?

## What belongs in CLAUDE.md:
- Tech stack changes (new dependencies, tools)
- Architectural decisions (patterns adopted, structure changes)
- Conventions established (naming, file organization, testing approach)
- Non-obvious gotchas or pitfalls discovered
- Integration details (APIs, external services)

## What does NOT belong:
- Task status or progress
- Temporary workarounds
- Feature-specific details (those go in spec.md)
- Anything that will be obvious from reading the code

Propose specific additions or edits to `CLAUDE.md`. Show me the diff before applying.