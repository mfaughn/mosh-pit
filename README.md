# claude-dev

Containerized Claude Code environment with Playwright MCP, configured for
Vertex AI authentication. Works with Podman (preferred) or Docker.

## Quick Start

```bash
# 1. Clone the repo
git clone <repo-url>
cd <repo-name>

# 2. Copy and edit the env file
cp .env.example .env
# Edit .env: fill in ANTHROPIC_VERTEX_PROJECT_ID and CLOUD_ML_REGION

# 3. Make sure gcloud credentials exist on host
gcloud auth application-default login

# 4. Run first-time setup (verifies config, builds image)
bash claude-dev.sh setup

# 5. Add to PATH (put in ~/.zshrc or ~/.bashrc)
export PATH="$PATH:/path/to/this/repo"
# Create a symlink for cleaner invocation
ln -s claude-dev.sh claude-dev

# 6. Use — just cd to any project and run
cd ~/projects/my-project
claude-dev
```

## Commands

```
claude-dev                          Launch (resumes existing container or creates new)
claude-dev ~/projects/app           Launch with a specific project directory
claude-dev ~/proj/fe ~/proj/be      Launch with multiple projects mounted

claude-dev setup                    First-time setup
claude-dev build                    Rebuild the container image
claude-dev save [tag]               Snapshot container as image (default tag: "backup")
claude-dev snapshots                List saved snapshots for current project
claude-dev restore [tag]            Restore container from a saved snapshot
claude-dev fresh                    Remove container and start clean from base image
claude-dev help                     Show help
```

## Container Persistence

Containers persist between sessions. When you exit Claude Code and later
re-run `claude-dev` from the same directory, the existing container is
restarted — any packages installed inside survive across sessions.

Each project gets its own container named `cc-<directory>` (e.g. `cc-my-app`).

Use `claude-dev save` to snapshot the container before risky changes, and
`claude-dev restore` to roll back if needed.

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
| `claude-dev.sh` | Setup and launcher script |
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
