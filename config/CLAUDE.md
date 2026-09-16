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

## Available Tools

The container ships with these CLI tools — prefer them when applicable:

- **`gh`** — GitHub CLI. Use for PR/issue/release ops, `gh api` for raw REST/GraphQL, `gh run` for Actions. Authenticated via `GITHUB_PERSONAL_ACCESS_TOKEN` if set in `.env`.
- **`rg` (ripgrep)** — Faster `grep`, respects `.gitignore`. Default choice for text search.
- **`fd`** — Faster `find`, respects `.gitignore`. Default choice for file lookups.
- **`ast-grep` (`sg`)** — Structural code search by AST pattern. Use for refactors and structural queries that regex can't express cleanly (e.g. "find all calls to `foo()` whose first arg is `null`").
- **`shellcheck`** — Lints shell scripts. Run before declaring a bash edit done.
- **`jq`** — JSON query/transform.
- **`tini`** — PID 1 init (transparent).

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

## Dev Servers and Ports

This container publishes a fixed set of ports to the host. Two rules, both of
which fail silently if ignored:

**1. Bind `0.0.0.0`, never `127.0.0.1`.** A server bound to loopback inside the
container is bound to the *container's* loopback, which the host cannot reach.
The symptom — connection refused from the browser — looks exactly like a broken
port mapping, so this is worth getting right the first time.

**2. Use a port from `$MOSH_PORTS`.** Only these container ports are published;
anything else is unreachable from the host no matter how it is bound.

```bash
echo "$MOSH_PORTS"   # e.g. 3000,4000,5173,8000,8080,8888,9000
echo "$MOSH_PORT"    # 3000 — the default to reach for
```

Examples:

```bash
python3 -m http.server "$MOSH_PORT" --bind 0.0.0.0
npm run dev -- --host 0.0.0.0 --port 5173
jekyll serve --host 0.0.0.0 --port 4000
```

The host-side URL is *not* the same number. The host port is offset per project
so that several containers can serve at once; `mosh ports` on the host prints the
mapping. Tell the user which container port you bound and let them map it, or
read `$MOSH_PORT_BASE` — host port = `$MOSH_PORT_BASE` + the index of your port
within `$MOSH_PORTS`.

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
