# Project Notes

## Architecture Decisions

### Config and Credentials Architecture (updated 2026-03-08)

The container's `~/.claude/` directory is split into two layers:

1. **Named Podman volume** (`cc-<project>-claude-home`, mounted as `/home/claude/.claude`):
   Fully writable. Created automatically on first launch. Persists across
   sessions — including `mosh fresh`. Stores credentials, Claude state, and
   any runtime writes from Claude Code.

2. **Repo bind mount** (`config/`, mounted read-only at `/mosh-config`):
   Contains the managed config files (settings.json, CLAUDE.md, agents/, etc.).
   At each launch, the startup command syncs these into the named volume so
   the container always has the latest versions.

**What this means in practice:**
- OAuth credentials survive `mosh fresh` (the volume is not deleted).
  To reset credentials, manually remove the volume: `podman volume rm cc-<project>-claude-home`
- Config file changes in `config/` take effect on next launch (copied in).
- Slash commands from `~/.claude/commands/` on the host are bind-mounted
  directly into the volume at `~/.claude/commands/`, overriding whatever
  the volume has at that path.

### Mirrored Files

These files exist in both `~/.claude/` (host) and `config/` (repo) but may diverge:

| File | Host (`~/.claude/`) | Container (synced from `config/`) |
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

### OAuth Token Persistence in Containers (2026-03-08)

**Symptom**: OAuth login flow completes ("Login successful"), but Claude
immediately shows "Not logged in · Please run /login". No token persisted.

**The investigation (what didn't work)**:

1. **gnome-keyring approach**: Assumed Claude Code on Linux used
   `libsecret`/`gnome-keyring` for OAuth storage (like some desktop apps do).
   Added `dbus` and `gnome-keyring` to the Containerfile and wrapped the launch
   command in `dbus-run-session -- bash -c 'gnome-keyring-daemon --unlock ...'`.
   Result: no change — login succeeded but token still didn't persist.

2. **Suppressed daemon output**: The gnome-keyring startup command used
   `>/dev/null 2>&1`, discarding the `GNOME_KEYRING_CONTROL` env var that
   applications use to find the daemon socket. Tried capturing and exporting
   it with `eval $(gnome-keyring-daemon --unlock ...)`. Still no change.

3. **Onboarding flag**: `config/claude.json` had `"hasCompletedOnboarding": true`
   which caused Claude to skip auth flow and render a blank cursor. Fixed by
   removing that key — separate bug, not the credentials issue.

4. **Mounting `~/.claude.json`**: Tried bind-mounting `config/claude.json`
   as `/home/claude/.claude.json` to inject MCP server config. This caused
   Claude to render only a blank cursor. Root cause unknown; mount removed
   entirely. MCP config is now handled differently.

**Root cause** (found by reading Claude Code's source):

Claude Code on Linux does **not** use gnome-keyring. It stores OAuth tokens
in a plain JSON file: `~/.claude/.credentials.json` (the `Tb8`/`"plaintext"`
storage backend in Claude Code's internal credential store, versus `VC4`/
`"keychain"` on macOS).

The `config/` directory was bind-mounted as `/home/claude/.claude/`. On macOS
with rootless Podman, bind-mounted directories retain their host ownership
(uid 501). The container user (`claude`, uid 1001) was mapped as "other", and
the directory permissions were `drwxr-xr-x` — no write for others. So every
call to write `.credentials.json` failed silently. Claude logged the failure
only to telemetry, not to the UI, so the user only saw "Login successful" then
"Not logged in".

**The fix**:

Replace the bind-mount of `config/` as `~/.claude/` with a **named Podman
volume**. Named volumes are owned by the container user inside the container,
so Claude Code can write freely. The repo's config files are now mounted
read-only at `/mosh-config/` and synced into the volume at each launch.

Key takeaway: on Linux, Claude Code credential storage requires a writable
`~/.claude/` directory. A bind-mounted host directory with a different UID
will silently fail all credential writes.

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

### Idle Session Hang — FUSE Stall (2026-03-10)

**Symptom**: Claude Code session left idle for ~3 days becomes completely
unresponsive. The process is alive (sleeping), the terminal is writable, but
Claude Code does not process input. No error message, no crash — just silent
refusal to respond.

**This is a different failure mode than the zombie accumulation** documented in
`tini-fix-brief.md`. Tini was running correctly as PID 1, and only 2 zombie
processes existed (harmless git processes from a separate session).

**What we observed (diagnostic session)**:

1. `ps aux`: Claude Code (PID 2) alive, state `Sl+` (sleeping, multi-threaded),
   0.1% CPU, 249MB RSS. Tini running as PID 1. Playwright MCP servers alive and
   idle. Only 2 zombies (git, from a second Claude session on pts/1).

2. `cat /proc/2/wchan`: `request_wait_answer` — a FUSE filesystem wait. The
   process was blocked waiting for the `fuse-overlayfs` daemon (inside the
   Podman Linux VM) to respond to a filesystem operation.

3. `cat /proc/2/net/tcp`: Empty — zero TCP connections. Not a stale network
   socket or expired API connection.

4. `echo "test" > /proc/2/fd/1`: Succeeded — the terminal (pts/0) was writable.
   The pty itself was not the bottleneck.

5. File descriptors: Two deleted files held open:
   - fd 22 → `~/.claude.json (deleted)`
   - fd 23 → `~/.claude/backups/.claude.json.backup... (deleted)`
   These are expected (Claude Code rewrites `.claude.json`), but if it tries to
   re-read the paths after deletion and the FUSE layer stalls, it blocks.

6. Thread-level check (second pass):
   - Main thread (TID 2): wchan `0`, syscall `running` — no longer in FUSE wait
   - Thread 3: `ep_poll` — Node.js event loop idle, waiting for events
   - All other threads: `futex_wait_queue` — worker threads idle
   Combined with 0.1% CPU and zero TCP connections, the process was alive but
   completely inert — not making API calls, not reading files, not doing anything.

**Likely cause**: After 3 days of macOS sleep/wake cycles, the Podman Linux VM's
FUSE overlay layer (`fuse-overlayfs`) did not fully recover. When Claude Code
tried to perform a filesystem operation (possibly triggered by user input after
the idle period), it blocked in `request_wait_answer`. The operation may have
eventually timed out internally, leaving Claude Code in a broken state where the
event loop was idle but not processing stdin.

**What we could NOT confirm** (container runs as non-root `claude` user):
- `/proc/2/stack` — permission denied
- `strace -p 2` — strace not installed, `apt-get` requires root
- Exact file path that triggered the FUSE stall

**Possible mitigations** (not yet implemented):
- Application-level heartbeat/keepalive that detects when the session is stale
- Periodic health check script that tests filesystem responsiveness inside the
  container and alerts or restarts if stuck
- Investigating Podman VM settings for FUSE timeout behavior after sleep/wake
- Adding strace to the container image for future diagnostics
- A watchdog process that monitors Claude Code's responsiveness

### Shared Bind Mount Cross-Contamination (2026-03-10)

**Symptom**: `~/.claude/projects/-workspace/` inside one container contained
session data from a completely different project running in a separate container.

**Root cause**: Containers created before the named volume migration (see "OAuth
Token Persistence" above) still use the old bind mount configuration:

```
/Users/mrf/projects/safeClaude/config -> /home/claude/.claude (bind)
```

Multiple containers (`cc-ezfhir`, `cc-drivetrain`, `cc-v2ig`) all bind-mount
the **same host directory** as `~/.claude/`. Since every container mounts its
project at `/workspace`, Claude Code's per-project state directory is always
`~/.claude/projects/-workspace/` — the same path in every container. All
containers read and write the same session files simultaneously.

**Confirmed by inspection**:

```
# cc-ezfhir mounts:
/Users/mrf/projects/safeClaude/config -> /home/claude/.claude (bind)
/Users/mrf/projects/ezfhir -> /workspace (bind)

# cc-drivetrain mounts:
/Users/mrf/projects/safeClaude/config -> /home/claude/.claude (bind)
/Users/mrf/projects/drivetrain -> /workspace (bind)
```

Same source directory for `~/.claude/`, different project at `/workspace`.
Only `cc-mosh-pit` had the named volume (`cc-mosh-pit-claude-home`).

**Why it persisted**: The `mosh` script's `cmd_launch` checks for an existing
container and resumes it (line 327–334) without recreating mounts. Containers
created before the named volume fix were never upgraded — they kept their old
bind mount configuration indefinitely.

**Additional concern**: The project was previously named `safeClaude`. Old
containers still reference `/Users/mrf/projects/safeClaude/config` as their
bind mount source. If that directory is renamed or removed, those containers
lose their `~/.claude/` entirely.

**The fix**: Recreate affected containers with `mosh fresh` so they pick up
the named volume mounts:

```bash
cd ~/projects/ezfhir && mosh fresh
cd ~/projects/drivetrain && mosh fresh
cd ~/projects/v2ig && mosh fresh     # if still running
```

Each will get its own named volume (`cc-ezfhir-claude-home`, etc.) with
isolated per-project state. Credentials will need re-authentication.

**Preventive measure to consider**: The `mosh` script could detect old
bind-mounted containers on resume and warn the user to run `mosh fresh`, or
automatically migrate them. Currently it silently resumes with whatever mount
configuration the container was originally created with.

## File Inventory

| File/Dir | Purpose | Committed? |
|----------|---------|------------|
| `Containerfile` | Container image definition (node:20 + claude code + playwright) | Yes |
| `compose.yaml` | Service definition, volumes, env wiring | Yes |
| `.env.example` | Template for secrets | Yes |
| `.env` | Actual secrets | No (gitignored) |
| `mosh` | Setup and launcher script | Yes |
| `config/` | Repo-managed config files, synced into container at launch | Yes |
| `config/settings.json` | YOLO permissions, denied WebSearch | Yes |
| `config/claude.json` | User-level config baseline (autoUpdates, etc.) | Yes |
| `config/mcp.json` | MCP server definitions | Yes |
| `config/CLAUDE.md` | Container-specific global preferences | Yes |
| `config/commands/` | Slash commands (mirrored from ~/.claude/commands/) | Yes |
| `config/uadf/` | UADF framework (mirrored from ~/.claude/uadf/) | Yes |
| `config/templates/` | Templates (mirrored from ~/.claude/templates/) | Yes |
| `config/agents/` | Custom subagents (web-researcher.md) | Yes |
| `NOTES.md` | This file — ongoing project notes | Yes |
| `README.md` | User-facing documentation | Yes |
