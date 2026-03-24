# mosh

Containerized Claude Code environment with Playwright MCP, configured for
Vertex AI authentication. Works with Podman (preferred) or Docker.

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
mosh save [tag]               Snapshot container as image (default tag: "backup")
mosh snapshots                List saved snapshots for current project
mosh restore [tag]            Restore container from a saved snapshot
mosh fresh                    Remove container and start clean from base image
mosh help                     Show help
```

## Container Persistence

Containers persist between sessions. When you exit Claude Code and later
re-run `mosh` from the same directory, the existing container is
restarted — any packages installed inside survive across sessions.

Each project gets its own container named `cc-<directory>` (e.g. `cc-my-app`).

Use `mosh save` to snapshot the container before risky changes, and
`mosh restore` to roll back if needed.

## Verifying MCP is Connected

Once inside Claude Code, run:
```
/mcp
```
You should see the `playwright` server listed as connected.

## How It Works

- **Filesystem isolation**: only your project directory is mounted into the
  container. Claude cannot touch anything else on your system.
- **Vertex AI auth**: your host gcloud credentials are mounted read-only.
  No credentials are baked into the image.
- **Persistent config**: Claude Code settings, MCP config, slash commands,
  and agents live in `config/` and are bind-mounted into the container.
- **Playwright MCP**: the `@playwright/mcp` server runs headlessly inside
  the container using a Chromium headless shell binary (compatible with
  ARM64 containers).
- **Web search delegation**: WebSearch is blocked for Opus on Vertex AI.
  A Sonnet-powered `web-researcher` subagent handles web searches instead.
- **YOLO mode**: the container runs with `--dangerously-skip-permissions`
  and all tools pre-approved. Host-side Claude Code is unaffected.

## Files

| File | Purpose |
|---|---|
| `Containerfile` | Container image (node:20 + Claude Code + Playwright) |
| `compose.yaml` | Service definition (reference / podman-compose users) |
| `mosh` | Setup and launcher script |
| `.env.example` | Template for secrets — copy to `.env` |
| `config/settings.json` | Container permissions, model, env vars |
| `config/claude.json` | Baseline user config with MCP servers |
| `config/mcp.json` | MCP server definitions (injected into claude.json each launch) |
| `config/CLAUDE.md` | Container-specific global preferences |
| `config/agents/` | Custom subagents (web-researcher) |
| `config/commands/` | Slash commands |
| `config/uadf/` | UADF framework |
| `NOTES.md` | Architecture decisions and project notes |

## Customizing

- **Add MCP servers**: edit `config/mcp.json`. Changes take effect next launch.
- **Change model**: edit `config/settings.json` (`"model"` field).
- **Add slash commands**: add `.md` files to `config/commands/`.
- **Adjust permissions**: edit `config/settings.json` (`"permissions"` field).

## MCP Servers

MCP servers are defined in `config/mcp.json` and injected into `~/.claude.json`
inside the container at the start of every session. Claude Code strips `mcpServers`
from `~/.claude.json` when it exits, so the injection runs on every launch — this
is intentional and expected.

**MCP servers with credentials** (e.g. `open-brain`) get their keys from `.env`,
not from `config/mcp.json`. The key is never committed to the repo. If a server's
key env var is missing from `.env`, that server is omitted silently.

**Setting up on a new machine**: copy `.env.example` to `.env` and fill in any
credential keys listed in the `MCP server credentials` section. Run `/mcp` inside
Claude to verify servers are connected.

**To reset MCP state**: just restart mosh — the injection always runs fresh.
