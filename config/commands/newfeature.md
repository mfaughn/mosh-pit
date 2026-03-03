# File: ~/.claude/commands/newfeature.md

---
description: Plan a new feature with spec interview
argument-hint: [feature-name]
---

# Feature Planning: $ARGUMENTS

We are adding a new feature: **$ARGUMENTS**

Interview me ONE question at a time about:
1. What problem does this feature solve?
2. User flow for this feature
3. Edge cases and error handling
4. How it integrates with existing code
5. Any new dependencies needed

Then:
1. Append feature spec to `spec.md` under a new section
2. Update `ARCHITECTURE.md` if structural changes needed
3. Add tasks to `tasks.md` for this feature
4. Log any significant decisions to `decisions.md`

Note: Do NOT update `CLAUDE.md` yet—we'll consolidate after implementation.

Confirm you understand, then ask the first question.