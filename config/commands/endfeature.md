# File: ~/.claude/commands/endfeature.md

---
description: Wrap up a feature and capture any learnings
argument-hint: [feature-name]
---

# Feature Completion: $ARGUMENTS

The feature **$ARGUMENTS** is being wrapped up.  If **$ARGUMENTS** is empty, the feature in question may be the one most recently being worked on.  When in doubt, please give me a list of recently features that you believe I may be referring to and ask me to indicate which one I wish to end.  

1. Review what was implemented vs. what was planned in `spec.md`
2. Check `decisions.md` for any decisions made during implementation
3. Ask me: "Did we establish any new patterns or conventions worth capturing?"

If yes to #3, propose a specific addition to `CLAUDE.md` (show diff, wait for approval).

Finally, mark relevant tasks complete in `tasks.md`.