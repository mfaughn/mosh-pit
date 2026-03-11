# Mosh Setup Guide

How to get mosh running on a new machine. Designed to be given to Claude Code on the target machine so it can automate as much as possible.

---

## Prerequisites (human must do these)

### 1. Install a container runtime

**Podman (preferred):**
```bash
# macOS
brew install podman
podman machine init
podman machine start

# Linux (Debian/Ubuntu)
sudo apt-get install -y podman
```

**Docker (alternative):**
```bash
# macOS
brew install --cask docker
# Then launch Docker Desktop

# Linux
# Follow https://docs.docker.com/engine/install/
```

### 2. Install Claude Code

```bash
npm install -g @anthropic-ai/claude-code
```

Verify: `claude --version`

### 3. Authenticate Claude Code

Run `claude` once and complete the authentication flow (OAuth browser login, API key, or Vertex AI — whichever you use). This creates `~/.claude/` on the host.

### 4. Clone the mosh-pit repo

```bash
cd ~/projects  # or wherever you keep repos
git clone https://github.com/mfaughn/mosh-pit.git
cd mosh-pit
```

---

## Automated setup (give the rest to Claude Code)

From here, run `claude` inside the `mosh-pit` directory and give it these instructions:

---

**Instructions for Claude Code:**

Run through these steps. Ask me for input where marked with ASK. Do everything else automatically.

### Step 1: Create .env

```bash
cp .env.example .env
```

**ASK:** "Which auth method? (a) OAuth / Claude Pro/Max — no keys needed, (b) Anthropic API key, (c) Vertex AI. And do you want to override the default model?"

- If (a): leave .env as-is
- If (b): uncomment and set `ANTHROPIC_API_KEY` in `.env`
- If (c): uncomment and set `ANTHROPIC_VERTEX_PROJECT_ID` and `CLOUD_ML_REGION` in `.env`

### Step 2: Set up host commands directory

The mosh container bind-mounts `~/.claude/commands/` for shared skills. Copy the UADF commands:

```bash
mkdir -p ~/.claude/commands/uadf
```

**ASK:** "Do you have UADF commands to copy from another machine or a backup? If so, provide the path. Otherwise I'll skip this — you can add commands later."

If the user has them, copy them into `~/.claude/commands/uadf/`. Expected files:
- `uadf-adr.md`
- `uadf-handoff.md`
- `uadf-help.md`
- `uadf-init.md`
- `uadf-start.md`

### Step 3: Set up host CLAUDE.md

If `~/.claude/CLAUDE.md` doesn't exist, create it. If it does, check whether it has a UADF section.

**ASK:** "Do you have a CLAUDE.md to copy from another machine? If so, provide the path or paste the contents."

If not, create a minimal one:

```markdown
# Global Preferences

## UADF (Universal Agentic Development Framework)

When I invoke any `/uadf-*` skill or say "use UADF", follow the framework defined in `~/.claude/uadf/framework.md`.

UADF adds session continuity (JOURNAL.md handoffs) and decision tracking (ADRs) on top of Claude Code's built-in capabilities.

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
```

### Step 4: Set up GitHub token (optional)

If the user wants the GitHub MCP plugin to work inside containers:

**ASK:** "Do you want to set up a GitHub personal access token for use in containers? If yes, provide the token."

If yes, add to `~/.claude/settings.json` under `env`:
```json
"GITHUB_PERSONAL_ACCESS_TOKEN": "<token>"
```

### Step 5: Build the image and run setup

```bash
bash mosh setup
```

This builds the container image (takes a few minutes on first run), verifies the configuration, and installs the `mosh` command to `/usr/local/bin`.

### Step 6: Verify

```bash
# Start a test container from any project directory
cd /tmp && mkdir test-project && cd test-project
mosh
```

Inside the container, verify:
- `ps aux | head -3` — tini should be PID 1
- Type `/skills` — should show uadf commands if they were installed
- Type `/exit` to quit

Clean up: `rm -rf /tmp/test-project`

---

## Notes

### Podman vs Docker differences

- `mosh` auto-detects the runtime — no config needed
- Podman runs rootless by default; Docker may need `sudo` or the user added to the `docker` group
- Podman uses a VM on macOS (`podman machine`); Docker Desktop handles this automatically
- If using Podman on macOS, ensure the machine has enough resources: `podman machine set --memory 8192 --cpus 4`

### Container persistence

Containers are named `cc-<project-dir>` and persist across restarts. Use:
- `mosh` — resumes existing container or creates new
- `mosh fresh` — removes existing and starts clean
- `mosh save [tag]` — snapshot container state
- `mosh restore [tag]` — restore from snapshot

### Per-project provisioning

If a project needs system packages inside the container, Claude Code will create `.claude-dev/provision.sh` in the project root. This runs automatically on fresh containers.

### File locations

| What | Where |
|------|-------|
| Launch script | `~/projects/mosh-pit/mosh` |
| Container image config | `~/projects/mosh-pit/Containerfile` |
| Container Claude config | `~/projects/mosh-pit/config/` |
| Host Claude config | `~/.claude/` |
| Host commands (shared) | `~/.claude/commands/` |
| Auth secrets | `~/projects/mosh-pit/.env` (gitignored) |
