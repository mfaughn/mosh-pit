---
name: uadf-adr
description: Record an Architecture Decision Record in docs/adr/.
argument-hint: "[decision title]"
disable-model-invocation: true
---

# Record an ADR: $ARGUMENTS

1. **Number it.** List `docs/adr/`. The new file is `docs/adr/NNNN-kebab-case-title.md`,
   where `NNNN` is the next number, zero-padded to four digits.

2. **Gather the content.** Usually the decision was discussed earlier in this session.
   Draft from that conversation, and ask the user only about what's missing: the context,
   the options considered, the decision and why, and the trade-offs accepted. If there was
   no earlier discussion, ask about these one question at a time.

3. **Write it** from `~/.claude/uadf/templates/adr-template.md`. Status is `Accepted`
   unless the user says it's only proposed. Use today's date.

4. **Update references.** If the decision changes a project convention, propose a line
   for the project's `CLAUDE.md`. Mention the ADR in the next journal entry.

5. **Commit** the ADR: `Add ADR-NNNN: <title>`.

6. **Show** the ADR and ask whether it captures the decision accurately.
