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

Similarly, if you install a plugin via `/plugin install` that is specific to
this project, append its name to `.claude-dev/plugins.txt` (one per line,
format: `name@marketplace`). These are also reinstalled on fresh containers.

## Web Search Policy
Do not use the WebSearch tool directly — it is blocked on this model. Instead,
always delegate web searches to the `web-researcher` subagent, which runs on a
model that has web search access. Use the Task tool with
`subagent_type: "general-purpose"` and `model: "sonnet"` or reference the
web-researcher agent file.

## UADF (Universal Agentic Development Framework)

When I invoke any `/uadf-*` skill or say "use UADF", follow the framework defined in `~/.claude/uadf/framework.md`.

UADF adds session continuity (JOURNAL.md handoffs) and decision tracking (ADRs) on top of Claude Code's built-in capabilities. Feature planning, TDD, code review, and agent teams are handled by native tools and official plugins.

**Core Principles:**
- Memory lives in files, not chat history
- Write a session handoff before ending so the next session can resume
- Work on feature branches, keep main deployable
- Record significant architectural decisions as ADRs

**Skills:**
- `/uadf-init` — Initialize project with JOURNAL.md and docs/adr/
- `/uadf-start` — Begin/resume a session
- `/uadf-handoff` — Write session handoff to JOURNAL.md
- `/uadf-adr` — Create Architecture Decision Record
