# Global Preferences (Container Environment)

## Working Style
- Ask clarifying questions before making significant changes
- Prefer simple, readable solutions over clever ones
- Explain reasoning when making architectural decisions
- When uncertain between approaches, present options rather than choosing arbitrarily

## Code Principles
- Favor explicit over implicit
- Write docstrings for public functions and classes
- Prefer coding styles and conventions that are intelligible and comprehensible by junior level developers when possible.
- Keep functions focused—if it needs "and" in the description, consider splitting

## Workflow
- ALWAYS run tests before considering a task complete
- Commit messages: concise but descriptive (imperative mood)
- Ask before deleting files or making destructive changes

## Communication
- Be direct; skip unnecessary preamble
- When I ask "why," explain the tradeoffs, not just the choice

## Container Package Tracking

This environment runs inside a container. When you install system packages
(apt, pip, npm -g, etc.) to get work done, also append the install command
to `.claude-dev/provision.sh` in the project root. Create the file with a
bash shebang if it doesn't exist. Keep the script idempotent (use
`apt-get install -y`, `pip install`, etc.). Example:

```bash
#!/usr/bin/env bash
set -euo pipefail
apt-get update && apt-get install -y --no-install-recommends default-jdk
pip install some-package
```

This file is checked into the project and automatically re-run when the
container is recreated with `claude-dev fresh`, so all project-specific
dependencies are restored without manual intervention.

## Web Search Policy
Do not use the WebSearch tool directly — it is blocked on this model. Instead,
always delegate web searches to the `web-researcher` subagent, which runs on a
model that has web search access. Use the Task tool with
`subagent_type: "general-purpose"` and `model: "sonnet"` or reference the
web-researcher agent file.

## UADF (Universal Agentic Development Framework)

When I invoke any `/uadf-*` skill or say "use UADF", follow the framework defined in `~/.claude/uadf/framework.md`.

**Core Rules:**
- Memory lives in files, not chat history
- No implementation until `blueprint.md` is approved
- All work on feature branches with checkpoint commits
- TDD lifecycle: RED → GREEN → REFACTOR
- Session handoff before ending (20-25 message limit)

**Skills:**
- `/uadf-init` — Initialize new project with UADF
- `/uadf-start` — Begin/resume a session
- `/uadf-task` — Start a task with TDD lifecycle
- `/uadf-handoff` — Write session handoff
- `/uadf-adr` — Create Architecture Decision Record
