# File: ~/.claude/commands/newproject.md

---
description: Initialize a new project with spec interview and planning documents
argument-hint: [project-name]
---

# Project Initialization: $ARGUMENTS

We are starting a new project called **$ARGUMENTS**.

We will use a memory-driven workflow. Before writing any code, you must interview me to create detailed planning documents.

## Interview Process
Ask me ONE question at a time about:
1. Core purpose and problem being solved
2. Target users
3. Key features and functionality
4. User flow / main interactions
5. Tech stack preferences
6. Constraints or requirements (deployment, performance, etc.)
7. Any integrations or external dependencies

## Deliverables
Once we have enough detail, generate these files in the project root:

1. **`CLAUDE.md`** — Project context file (THIS IS PRIMARY). Include:
   - Project overview (1-2 sentences)
   - Tech stack
   - File structure conventions
   - Coding conventions specific to this project
   - Key architectural decisions with brief rationale

2. **`spec.md`** — Detailed specification (features, user stories, acceptance criteria). Follow structure in @~/.claude/templates/spec.md

3. **`ARCHITECTURE.md`** — System architecture, data models, component relationships, diagrams. Follow structure in @~/.claude/templates/architecture.md

4. **`tasks.md`** — Prioritized task list with dependencies noted. Follow structure in @~/.claude/templates/tasks.md

5. **`decisions.md`** — Decision log (initially empty). Format:
```
   ## YYYY-MM-DD: [Decision Title]
   **Context:** Why this came up
   **Decision:** What we decided
   **Rationale:** Why
```

Adapt the templates based on interview answers. Do not copy them verbatim—fill in and modify sections as appropriate.
