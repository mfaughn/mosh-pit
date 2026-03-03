# Project Notes

## Architecture Decisions

### Separate Config Directories (2026-02-24)

The container uses its own Claude Code configuration, separate from the host
`~/.claude/` directory. This is intentional:

- **Host** (`~/.claude/`): Used when running Claude Code directly on macOS.
  Standard permissions, interactive approval mode.
- **Container** (`config/` in this repo, mounted as `/home/claude/.claude`): Used
  inside the container. YOLO mode with permissive settings. All tools
  pre-approved in `settings.json`.

**What this means in practice:**
- If you add a new slash command to `~/.claude/commands/`, you must also copy
  it to `config/commands/` if you want it available in the container.
- The container's `settings.json` has different permissions than the host's.
  The container version allows all tools and denies only `WebSearch` (which is
  delegated to a Sonnet-powered subagent).
- Changes to files in `config/` take effect on the next container start (no
  rebuild needed, since it's a bind mount).

### Mirrored Files

These files exist in both `~/.claude/` and `config/` but may diverge:

| File | Host (`~/.claude/`) | Container (`config/`) |
|------|--------------------|-----------------------|
| `CLAUDE.md` | Standard preferences | Adds web search policy |
| `settings.json` | Limited permissions, sonnet default | YOLO permissions, WebSearch denied |
| `commands/*.md` | Same content | Same content (manually synced) |
| `uadf/` | Same content | Same content (manually synced) |
| `templates/` | Same content | Same content (manually synced) |
| `agents/` | Does not exist on host | `web-researcher.md` for search delegation |

### Web Search Delegation (2026-02-24)

The Vertex AI organization policy blocks `web_search` for Opus 4.6 but allows
it for Sonnet 4.5. To work around this:

- `WebSearch` is denied in the container's `settings.json`
- A custom subagent `config/agents/web-researcher.md` is configured with
  `model: sonnet`, which has web search access
- The container's `CLAUDE.md` instructs Claude to use this subagent for all
  web searches instead of calling WebSearch directly

### Launch Modes (2026-02-24)

The `claude-dev.sh` script supports three launch modes:

1. **No arguments** — mounts `$(pwd)` as `/workspace`
2. **Single path** — `claude-dev ~/projects/app` mounts it as `/workspace`
3. **Multiple paths** — `claude-dev ~/proj/fe ~/proj/be` mounts each as
   `/workspace/<dirname>` (e.g. `/workspace/fe`, `/workspace/be`)

Multi-project mode bypasses `compose.yaml` and calls `podman run` directly
because compose doesn't support dynamic volume lists. Single-project mode
also uses `podman run` directly for consistency.

The compose.yaml is still useful as documentation and for `podman-compose`
users who want to invoke it directly.

### Chromium in Containers on ARM64 (2026-02-24)

The full Chrome binary (`chrome-linux/chrome`) crashes with `SIGTRAP` on ARM64
in podman containers. The `chrome_crashpad_handler` subprocess cannot initialize,
and the crash is not fixable with `--no-sandbox`, `--shm-size`, or disabling
crashpad alone.

**Solution**: Use the headless shell binary (`chromium_headless_shell-XXXX/
chrome-linux/headless_shell`) instead. This binary works reliably in containers.
The MCP config specifies it via `--executable-path`.

Additionally, the MCP server (`@playwright/mcp@latest`) and the Python
`playwright` package may bundle different playwright-core versions that expect
different Chromium builds (e.g. 1208 vs 1212). The Containerfile installs
browsers for both versions to avoid "browser not installed" errors.

### MCP Server Registration (2026-02-24)

Claude Code overwrites `~/.claude.json` on exit, stripping manually-added
`mcpServers` entries. The `.mcp.json` project-level config requires a trust
dialog that doesn't persist reliably.

**Solution**: The launch script (`claude-dev.sh`) injects MCP server config
from `config/mcp.json` into `config/claude.json` using a Python one-liner
before every container launch. This runs on the host side before the container
starts, so it's always fresh.

### Base Image (2026-02-24)

There is no official `anthropic/claude-code` Docker image. The Containerfile
uses `node:20` as the base and installs Claude Code via
`npm install -g @anthropic-ai/claude-code@latest`. This matches the approach
used in Anthropic's official devcontainer reference at
https://github.com/anthropics/claude-code/tree/main/.devcontainer

### Config File Naming

Claude Code uses two separate config files:

- `~/.claude/settings.json` — permissions, model, env vars, effort level
- `~/.claude.json` — MCP servers, user state, onboarding, project data

MCP servers must go in `~/.claude.json`, NOT in `settings.json`. In the
container, these map to:

- `config/settings.json` → `/home/claude/.claude/settings.json`
- `config/claude.json` → `/home/claude/.claude.json`

## File Inventory

| File/Dir | Purpose | Committed? |
|----------|---------|------------|
| `Containerfile` | Container image definition (node:20 + claude code + playwright) | Yes |
| `compose.yaml` | Service definition, volumes, env wiring | Yes |
| `.env.example` | Template for secrets | Yes |
| `.env` | Actual secrets | No (gitignored) |
| `claude-dev.sh` | Setup and launcher script | Yes |
| `config/` | Container-specific Claude Code config (mounted as /home/claude/.claude) | Yes |
| `config/settings.json` | YOLO permissions, denied WebSearch | Yes |
| `config/claude.json` | User-level state, MCP servers (re-injected each launch) | Yes |
| `config/mcp.json` | MCP server definitions (source of truth for injection) | Yes |
| `config/CLAUDE.md` | Container-specific global preferences | Yes |
| `config/commands/` | Slash commands (mirrored from ~/.claude/commands/) | Yes |
| `config/uadf/` | UADF framework (mirrored from ~/.claude/uadf/) | Yes |
| `config/templates/` | Templates (mirrored from ~/.claude/templates/) | Yes |
| `config/agents/` | Custom subagents (web-researcher.md) | Yes |
| `HANDOFF.md` | Original planning conversation handoff | Yes |
| `NOTES.md` | This file — ongoing project notes | Yes |
| `README.md` | User-facing documentation | Yes |
