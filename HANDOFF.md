# Claude Code Project Handoff: claude-dev Container Environment

## Who You Are Talking To

This document was written by Claude (claude.ai) to hand off a project to Claude Code. You are Claude Code, picking up where a planning conversation left off. The human working with you is Michael — a senior healthcare IT standards expert and developer at NIST who uses Python as his primary language for new projects and is deeply interested in AI tooling and workflows.

---

## What This Project Is

You are helping Michael build and maintain a **containerized Claude Code development environment** — essentially a self-contained, reproducible sandbox that lets him run Claude Code (you) in YOLO mode (`--dangerously-skip-permissions`) safely, across multiple projects, without risk to his host system or the NIST network infrastructure he works on.

The container approach was chosen deliberately:
- It limits filesystem access to only the mounted project directory
- It gives Claude Code full autonomy within that sandbox without alarming supervisors
- It creates a reproducible, version-controlled environment that can be spun up per-project
- It is explainable and defensible in a federal government context

---

## Current State of the Files

All files live in a single directory (e.g. `~/tools/claude-dev/`). Here is what exists and what each file does:

### `Containerfile`
Extends `anthropic/claude-code:latest` (the official Anthropic base image). Adds:
- Python 3 + pip (Michael's preferred language for new work)
- All Playwright system dependencies (libgbm, libnss3, etc.)
- `playwright` Python package + Chromium browser binary installed to `/ms-playwright`
- `@playwright/mcp@latest` npm package (the official Microsoft Playwright MCP server)

The entrypoint is `claude --dangerously-skip-permissions`.

### `compose.yaml`
Defines the `claude` service. Key behaviors:
- Loads all environment variables from `.env`
- Mounts `${PROJECT_DIR:-.}` (defaults to current directory) to `/workspace` in the container
- Mounts `${GCLOUD_CONFIG_DIR:-~/.config/gcloud}` read-only for Vertex AI auth
- Mounts `${CLAUDE_CONFIG_DIR:-~/.claude-dev-config}` for persistent Claude Code config and MCP settings
- Sets `CLAUDE_CODE_USE_VERTEX=1`, `PLAYWRIGHT_BROWSERS_PATH=/ms-playwright`

### `.env.example`
Template for secrets. Required fields:
- `ANTHROPIC_VERTEX_PROJECT_ID` — GCP project with Vertex AI Claude access
- `CLOUD_ML_REGION` — Vertex AI region (e.g. `us-east5`)

Never committed. The actual `.env` is gitignored.

### `claude_mcp_config.json`
MCP server configuration. Currently configures one server:
- `playwright` — runs `npx -y @playwright/mcp@latest --headless --browser chromium`

This file gets copied to `~/.claude-dev-config/claude_mcp_config.json` by the setup script, which is the path Claude Code reads it from inside the container.

### `claude-dev.sh`
The main launcher script. Supports three commands:
- `setup` — copies `.env.example` → `.env`, creates `~/.claude-dev-config/`, installs MCP config, builds image
- `build` — builds/rebuilds the container image
- `(no args)` — launches Claude Code in the current directory via `podman-compose run --rm claude`

Auto-detects `podman` vs `docker` and `podman-compose` vs `docker-compose`.

### `.gitignore`
Ignores `.env` and OS noise.

### `README.md`
Quick-start instructions and file reference.

---

## Michael's Authentication Setup

**Important**: Michael accesses Claude through **Vertex AI API keys**, not direct Anthropic API keys and not claude.ai subscription. This means:
- `CLAUDE_CODE_USE_VERTEX=1` must always be set
- `ANTHROPIC_VERTEX_PROJECT_ID` and `CLOUD_ML_REGION` must be set
- Google Application Default Credentials from `~/.config/gcloud` are mounted into the container read-only
- There is no `ANTHROPIC_API_KEY` in play — do not add one

The Chrome extension for Claude cannot be used because it requires claude.ai login, which doesn't work with Vertex AI API keys.

---

## What Needs to Be Done Next

This is an evolving setup. Michael has described the following goals, in rough priority order:

### 1. Skills Support (High Priority)
Claude Code supports "skills" — markdown files placed in `.claude/skills/` within a project (or a global skills directory) that give Claude Code domain-specific instructions and best practices for particular tasks. Michael wants to:
- Understand where Claude Code looks for skills files (project-level vs global)
- Define a set of personal/preferred skills he wants available in every container session
- Find a good place in the project structure to store and manage these skills
- Have the setup script (or Containerfile) ensure skills are available inside the container

**Research needed**: Confirm the exact path(s) Claude Code reads skills from, whether there is a global skills directory configurable via env var or settings, and how project-level vs global skills interact.

### 2. Per-Project Container Variants
Michael wants to be able to run multiple containers simultaneously, one per project, each with:
- Its own project directory mount
- Potentially different skill sets or MCP tools per project
- Shared base image (don't rebuild everything per project)
- Clean separation so projects don't bleed into each other

This probably means either:
- A `compose.yaml` override pattern (base compose + project-specific override files)
- A wrapper script that accepts a project name and generates the right mounts
- Or named Claude config profiles per project

### 3. Additional MCP Servers
The current setup only has Playwright. Michael is interested in MCP and wants to easily add more servers. Good candidates to consider:
- A filesystem MCP server for more structured file operations
- Potentially others as needs emerge

The `claude_mcp_config.json` should be easy to extend. Consider whether it should be templated or split into a base config + project-specific additions.

### 4. Testing and Validation
The files have not been tested yet — they were designed in a planning conversation. First order of business should be:
- Attempt an actual build and surface any errors
- Verify Vertex AI auth works inside the container
- Verify `/mcp` inside Claude Code shows the playwright server as connected
- Verify a basic Playwright tool call works (e.g. navigate to a URL and take a screenshot)

### 5. Workflow Polish
Once the basics work:
- Consider a `claude-dev new <project-name>` command that sets up a new project directory with a `.claude/` skeleton
- Consider whether skills should live in this repository or be pulled from a separate dotfiles-style repo
- Document the actual tested commands in README.md

---

## Constraints and Preferences to Keep In Mind

- **Python first**: Michael prefers Python for any scripting. If there's a choice between a bash solution and a Python solution for tooling, lean toward Python unless bash is clearly simpler.
- **Podman, not Docker**: Primary container runtime is Podman. Everything should work with Podman. Docker compatibility is a nice-to-have, not a requirement.
- **Federal environment awareness**: Avoid solutions that require outbound network calls to unexpected destinations, require browser login flows, or would look alarming to a network security team. Keep the setup auditable and explainable.
- **No ANTHROPIC_API_KEY**: Michael's auth is entirely Vertex AI. Don't introduce direct Anthropic API key usage.
- **Git hygiene**: Secrets never in git. Infrastructure-as-code (Containerfile, compose, scripts) is committed. Personal config (`.env`, credentials) is not.

---

## Suggested First Steps for This Session

1. Read all the existing files carefully to understand what's there.
2. Attempt to build the image and report any errors. Fix them.
3. Research the Claude Code skills system — specifically where skills files live and how to make personal skills available globally inside the container.
4. Propose a skills directory structure and how to wire it into the container setup.
5. Then proceed with Michael's direction from there.

---

## File Locations

All files should be in the directory where you were invoked. If you need to confirm the structure:
```bash
ls -la
```

The persistent Claude config directory on the host (mounted at `/root/.claude` inside the container) is `~/.claude-dev-config/`. The MCP config that Claude Code reads is at `~/.claude-dev-config/claude_mcp_config.json`.

---

*This handoff document was generated by Claude (claude.ai) on 2026-02-24 to support continuity between a planning conversation and a Claude Code work session.*
