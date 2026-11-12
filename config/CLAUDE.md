# Global Preferences (Container Environment)

## How I like to work
- I make the architectural calls. For a choice with real trade-offs (a new
  dependency, a data model, how components fit together), give me the options and
  your recommendation, and let me pick.
- You don't need to check in for routine steps: reading and editing files in the
  project, running tests, builds and linters, and installing packages (tracked as
  described below).
- Ask before deleting files, rewriting git history, pushing, or sending anything off
  this machine. Those are hard to undo.
- When I ask "why", explain the trade-offs, not just the choice.

## Code
- Write code a junior developer can follow: simple and explicit beats clever.
- Write docstrings for public functions and classes.

## Finishing a task
- Run the project's tests before calling a task done. If there is no test suite, say
  what you checked instead. For shell scripts, that means `shellcheck` and `bash -n`.
- Commit messages: imperative mood, concise but descriptive.

## Available Tools

Besides the usual tools, the container has:

- **`gh`**: GitHub CLI, authenticated via `GITHUB_PERSONAL_ACCESS_TOKEN` from `.env`.
  `gh api` covers raw REST/GraphQL.
- **`rg`**, **`fd`**: fast grep and find that respect `.gitignore`.
- **`ast-grep` (`sg`)**: structural search by AST pattern, for refactors that regex
  can't express cleanly.
- **`shellcheck`**, **`jq`**.

## Container Package Tracking

Packages you install by hand are lost when the container is recreated with
`mosh fresh`. So when you install a system package (apt, pip, npm -g, etc.), also
append the install command to `.claude-dev/provision.sh` in the project root. Create
it with a bash shebang and `set -euo pipefail` if it doesn't exist, and keep it
idempotent (`apt-get install -y`, etc.). `mosh` re-runs it on fresh containers.

Likewise, append a project-specific plugin installed via `/plugin install` to
`.claude-dev/plugins.txt`, one `name@marketplace` per line.

## Dev Servers and Ports

Two rules. Breaking either one fails silently, with "connection refused" in the
host's browser:

1. **Bind `0.0.0.0`, not `127.0.0.1`.** Loopback inside the container is the
   container's own loopback, which the host can't reach.
2. **Use a port from `$MOSH_PORTS`** (`$MOSH_PORT` is the default). Only those
   container ports are published to the host.

The host port is a different number: each project gets its own offset. Host port =
`$MOSH_PORT_BASE` + the index of your port within `$MOSH_PORTS`, and `mosh ports` on
the host prints the mapping. Tell me which container port you bound.

## Web Research

The `WebSearch` tool does not work here. The LiteLLM gateway's Vertex project has an
org policy that rejects web search (`constraints/vertexai.allowedPartnerModelFeatures`),
in the main session and in subagents alike. Only a GCP admin can change that.

To search, fetch a search engine's results page instead:
`WebFetch https://www.bing.com/search?q=your+query`, asking for the result titles and
URLs quoted exactly. DuckDuckGo returns a CAPTCHA and Brave rate-limits, so use Bing.
Then fetch the pages the results point to.

Use the `web-researcher` subagent when the research is bulky enough that its page
fetches would crowd this context.

### Getting reliable results out of WebFetch

WebFetch returns a small model's summary of the page, not the page itself, and that
summary can misreport values without any sign of it. Example: a release published
`2026-11-10T20:01:54Z` came back as "November 10, 2024". Treat numbers, dates,
versions and identifiers from WebFetch as unverified until confirmed:

- **When an exact value matters, use `curl` from Bash.** It returns the raw bytes
  with no summarizer in between.
- **Prefer raw, structured sources**: `api.github.com` or `raw.githubusercontent.com`
  over rendered GitHub pages, `.md` versions of docs pages, and primary sources over
  aggregators.
- **Ask for the exact field, quoted verbatim**, and tell it to reply NOT PRESENT if
  the field isn't there. Without that escape, a missing fact tends to come back as a
  plausible invention.
- **Re-fetch anything that matters** with a differently worded prompt. If two fetches
  disagree, trust neither until a third source settles it.
- **Use `offset` on long pages.** A summary of a truncated page looks the same as a
  summary of a whole one.
- **Check unfamiliar URLs before dismissing them.** `github.com/podman-container-tools/podman`
  looked invented but was real: Podman had moved orgs.

## UADF

"Use UADF" or any `/uadf-*` command means following `~/.claude/uadf/framework.md`:
session handoffs in `JOURNAL.md` and decision records in `docs/adr/`.
