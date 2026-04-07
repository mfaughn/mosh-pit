# mosh

Containerized Claude Code environment with Playwright MCP and automatic
session resume. Works with Podman (preferred) or Docker. Supports OAuth
(Claude Pro/Max), direct API keys, and Vertex AI authentication.

## Quick Start

```bash
# 1. Clone the repo
git clone <repo-url>
cd <repo-name>

# 2. Copy and edit the env file
cp .env.example .env
# Edit .env — for OAuth (Claude Pro/Max), leave it as-is.
# For API key or Vertex AI, uncomment and fill in the relevant vars.

# 3. Run first-time setup (builds image, installs mosh to /usr/local/bin)
bash mosh setup

# 4. Use — just cd to any project and run
cd ~/projects/my-project
mosh
```

## Commands

```
mosh                          Launch (resumes last session and container)
mosh new                      Start a fresh session (skip session resume)
mosh ~/projects/app           Launch with a specific project directory
mosh ~/proj/fe ~/proj/be      Launch with multiple projects mounted

mosh setup                    First-time setup
mosh build                    Rebuild the container image
mosh fresh                    Remove container and start clean from base image
mosh update                   Update Claude Code inside existing container
mosh provision                Re-run provision script in existing container
mosh save [tag]               Snapshot container as image (default tag: "backup")
mosh snapshots                List saved snapshots for current project
mosh restore [tag]            Restore container from a saved snapshot
mosh help                     Show help
```

## Authentication

Mosh supports three auth modes. Configure in `.env`:

- **OAuth (Claude Pro/Max)**: leave API key vars commented out. Claude Code
  prompts for browser login on first launch. Credentials persist in a
  per-project named volume.
- **Direct API key**: set `ANTHROPIC_API_KEY` in `.env`.
- **Vertex AI**: set `ANTHROPIC_VERTEX_PROJECT_ID` and `CLOUD_ML_REGION`.
  Host gcloud credentials are mounted read-only.

## Container Persistence

Containers persist between sessions. When you exit Claude Code and later
re-run `mosh` from the same directory, the existing container is
restarted — any packages installed inside survive across sessions.

Each project gets its own container named `cc-<directory>` (e.g. `cc-my-app`).
Multi-project launches combine names: `cc-frontend-backend`.

A per-project named volume at `~/.claude` preserves credentials, session
history, and plugin state across container recreation.

Use `mosh save` to snapshot the container before risky changes, and
`mosh restore` to roll back if needed.

## Environment Variables

Variables in `.env` are resolved using the host shell environment before
being passed to the container. This means you can reference host variables:

```bash
# In .env — $GITHUB_TOKEN is expanded from your ~/.zshenv or shell env
GITHUB_PERSONAL_ACCESS_TOKEN=$GITHUB_TOKEN
MY_SECRET=$MY_SECRET
```

Only variables listed in `.env` are passed through — the full host
environment is not leaked into containers.

**Important**: env vars are baked in at container creation time. If you
change `.env`, run `mosh fresh` for the changes to take effect. Resuming
an existing container (`mosh`) uses the original env.

## Provisioning

When Claude Code installs system packages in a container, it can record
them in `.claude-dev/provision.sh` in your project directory. This script
runs automatically when creating new containers, so dependencies are
restored on `mosh fresh`.

Per-project plugins can be listed in `.claude-dev/plugins.txt` (one per
line). Default plugins shared across all projects live in
`config/default-plugins.txt`.

On new containers, Claude Code is automatically updated to the latest
version before provisioning runs.

## Project-Specific Configuration

Since your project directory is bind-mounted, Claude Code's native
project-level config works out of the box:

- **Project commands**: `.claude/commands/` — slash commands for this project only
- **Project settings**: `.claude/settings.local.json` — project-specific overrides
- **Project instructions**: `CLAUDE.md` — project-specific guidance

Global config from `config/` provides the baseline; project-level files
layer on top.

## How It Works

- **Filesystem isolation**: only your project directory is mounted into the
  container. Claude cannot touch anything else on your system.
- **Config sync**: settings, MCP config, slash commands, status line script,
  and agents from `config/` are synced into `~/.claude` at every launch.
- **Session resume**: Claude Code session IDs are saved on exit and
  automatically resumed on next launch. Use `mosh new` for a fresh session.
- **Persistent config**: `~/.claude` lives in a named volume so credentials,
  plugins, and session state persist across `mosh fresh`.
- **Playwright MCP**: the `@playwright/mcp` server runs headlessly inside
  the container using a Chromium headless shell binary (compatible with
  ARM64 containers).
- **Host commands**: slash commands from `~/.claude/commands/` on the host
  are bind-mounted into the container so both environments share the same
  commands.
- **YOLO mode**: the container runs with `--dangerously-skip-permissions`
  and all tools pre-approved. Host-side Claude Code is unaffected.

## Files

| File | Purpose |
|---|---|
| `Containerfile` | Container image (node:20 + Claude Code + Playwright) |
| `mosh` | Setup and launcher script |
| `.env.example` | Template for secrets — copy to `.env` |
| `config/settings.json` | Container permissions, model, env vars, status line |
| `config/claude.json` | Baseline user config (theme, onboarding, MCP servers) |
| `config/mcp.json` | MCP server definitions (injected into claude.json each launch) |
| `config/statusline.sh` | Status line script (model, context %, duration, branch) |
| `config/CLAUDE.md` | Container-specific global preferences |
| `config/default-plugins.txt` | Plugins installed in all new containers |
| `config/git-credential-helper` | GitHub token auth helper for containers |
| `config/agents/` | Custom subagents (web-researcher) |
| `config/uadf/` | UADF framework files |

## Customizing

- **Add MCP servers**: edit `config/mcp.json`. Changes take effect next launch.
- **Change model**: edit `config/settings.json` (`"model"` field).
- **Add slash commands**: add `.md` files to `~/.claude/commands/` on the host
  (shared with all containers) or `<project>/.claude/commands/` (project-specific).
- **Adjust permissions**: edit `config/settings.json` (`"permissions"` field).
- **Add env vars**: add to `.env`, then `mosh fresh` to pick them up.

## MCP Servers

MCP servers are defined in `config/mcp.json` and injected into `~/.claude.json`
inside the container at the start of every session. Claude Code strips `mcpServers`
from `~/.claude.json` when it exits, so the injection runs on every launch — this
is intentional and expected.

**MCP servers with credentials** (e.g. `open-brain`) get their keys from `.env`,
not from `config/mcp.json`. The key is never committed to the repo. If a server's
key env var is missing from `.env`, that server is omitted silently.

**Project-specific MCP servers** can be configured in
`<project>/.claude/settings.local.json` — they only apply to that project's
container.

**To reset MCP state**: just restart mosh — the injection always runs fresh.
