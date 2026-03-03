---
description: Create an Architecture Decision Record
argument-hint: [decision-title]
---

# ADR: $ARGUMENTS

Creating an Architecture Decision Record for: **$ARGUMENTS**

## Determine ADR Number

Check existing ADRs:
```bash
ls docs/adr/ 2>/dev/null || echo "No ADRs yet"
```

The new ADR will be `docs/adr/NNNN-[kebab-case-title].md` where NNNN is the next number.

## Interview

Ask me ONE question at a time:

1. **Context:** What situation prompted this decision? What problem are we solving?
2. **Options:** What alternatives did we consider?
3. **Decision:** What did we choose and why?
4. **Trade-offs:** What are we giving up? What risks are we accepting?

## Create ADR

Using the template at @~/.claude/uadf/templates/adr-template.md, create the ADR:

```bash
mkdir -p docs/adr
```

Create `docs/adr/NNNN-[kebab-case-title].md` with:
- Status: Accepted (unless we're just proposing)
- Today's date
- Context from interview
- Decision
- Consequences (Good/Bad/Neutral)
- Alternatives considered

## Update References

If this decision affects other documents:
- Update `ARCHITECTURE.md` if it changes system design
- Add a note to `JOURNAL.md` referencing the ADR
- Update `CLAUDE.md` if it changes project conventions

## Commit

```bash
git add docs/adr/
git commit -m "docs: add ADR-NNNN $ARGUMENTS"
```

## Confirm

Show me the created ADR and ask:
"ADR created. Does this accurately capture the decision?"
