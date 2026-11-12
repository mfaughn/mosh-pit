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

## Web Research

`WebSearch` is available directly — use it. The old policy here said to delegate
searches to the `web-researcher` subagent because WebSearch was "blocked on this
model." That was self-inflicted: `deny: ["WebSearch"]` in `config/settings.json`
removed the tool, and a bare-name deny strips a tool from **subagents as well as
the parent**, so delegating could never restore it. The subagent ran with only
`WebFetch` and answered by guessing URLs. The deny has been removed.

The `web-researcher` subagent is still useful for farming out bulky research so
its page-fetching does not fill this context — but it is a context-management
choice now, not a capability workaround.

### Getting reliable results out of WebFetch

**WebFetch does not hand you the page.** It runs the content through a small, fast
summarizing model and returns that summary. The summarizer misreads things, and it
does so silently and confidently. Observed failure: a GitHub release page whose
publish date was reported as "November 10, **2024**" when the actual value was
`2026-11-10T20:01:54Z` — wrong by two years, with no hint anything was off.

Treat every number, date, version and identifier from WebFetch as unverified until
confirmed. In practice:

- **Fetch raw structured data, not rendered pages.** `api.github.com/repos/OWNER/
  REPO/releases/latest` instead of the HTML releases page; `raw.githubusercontent.com`
  instead of a `github.com/.../blob/...` view. JSON gives the summarizer far less room
  to paraphrase a value into something wrong.
- **Name the exact field you want and demand it verbatim.** "Report the literal
  `published_at` field" beats "when was this released?". Add "quote exactly, do not
  paraphrase."
- **Give it an explicit way to say nothing.** "If no such sentence exists, reply
  NOT PRESENT." Without that, an absent fact tends to come back as a plausible
  invention.
- **Re-fetch to confirm anything load-bearing.** A second fetch with a narrower,
  differently-worded prompt is cheap and catches exactly the date-style error above.
  If two fetches disagree, trust neither until a third source settles it.
- **Prefer a primary source over an aggregator.** Version-tracker sites lag and
  contradict each other; the project's own API or repo does not.
- **Use `offset` for long pages** rather than hoping one call covered the whole
  document. A summary of a truncated page looks identical to a summary of a whole one.
- **Do not assume an unfamiliar URL is fabricated — check it.** A search returned
  `github.com/podman-container-tools/podman`; it was dismissed as a hallucination
  because the known repo is `containers/podman`. It was real — Podman moved to a
  CNCF-owned org and that repo has 33k stars. Verify before disbelieving, the same
  way you verify before believing. Both errors cost the same.

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
