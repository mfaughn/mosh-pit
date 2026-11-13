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
  read-only at `~/.claude/commands/`, overriding whatever the volume has at
  that path. Skills are not shared this way: UADF's skills are copied from
  `config/uadf/skills/` into `~/.claude/skills/` at launch.

### Mirrored Files

These files exist in both `~/.claude/` (host) and `config/` (repo) but may diverge:

| File | Host (`~/.claude/`) | Container (synced from `config/`) |
|------|--------------------|-----------------------|
| `CLAUDE.md` | Standard preferences | Adds container tools, ports, package tracking and web search notes |
| `settings.json` | Limited permissions, sonnet default | Auto mode (set by `launch.sh`), `Read(.env)` denied, effort `high` |
| `commands/*.md` | Source | Bind-mounted read-only from the host (not copied) |
| `uadf/` | Symlinked to `config/uadf/` by `install-host.sh` | Copied from `config/uadf/` at launch; skills to `~/.claude/skills/` |
| `agents/` | Does not exist on host | `web-researcher.md` for search delegation |

### Web Search (updated 2026-11-12)

The `WebSearch` tool does not work in containers, for any model, in the main
session or a subagent. Every call fails with the Vertex org-policy error
`constraints/vertexai.allowedPartnerModelFeatures … web_search`. Only a GCP admin
can lift that.

The workaround is to fetch a search engine's results page with WebFetch or `curl`.
Bing works; DuckDuckGo returns a CAPTCHA and Brave returns 429. The container
`CLAUDE.md` says how, and `config/agents/web-researcher.md` does the same for bulky
research.

History: in 2026-02 the policy blocked Opus but allowed Sonnet, so `WebSearch` was
denied in `settings.json` and a Sonnet subagent did the searching. The policy has
since tightened to every model, so that setup stopped working.

A SearXNG server on the host would be a better search backend. The Cowork plugin
publishes it only on the Mac's `127.0.0.1:8888`, so containers can't reach it
(`host.containers.internal:8888` is refused). Publishing it more widely would expose
an unauthenticated server to every network the Mac joins. The plan instead (2026-11-13)
is a shared Podman network, `websearch`: the plugin's `searxng-up.sh` attaches SearXNG
to it, and `mosh` puts new containers on it, so they reach `http://searxng:8080`.

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

### Launch Modes (2026-02-24, script renamed to `mosh` since)

`mosh` supports three launch modes:

1. **No arguments** — mounts `$(pwd)` as `/workspace`
2. **Single path** — `mosh ~/projects/app` mounts it as `/workspace`
3. **Multiple paths** — `mosh ~/proj/fe ~/proj/be` mounts each as
   `/workspace/<dirname>` (e.g. `/workspace/fe`, `/workspace/be`)

All modes call `podman run` directly. There was once a `compose.yaml`, but
compose can't express dynamic volume lists for multi-project mode, so nothing
ever invoked it. It was removed in the LiteLLM gateway migration (it still
hardcoded `CLAUDE_CODE_USE_VERTEX: "1"`, which would have been a trap for
anyone who ran it by hand).

### Chromium in Containers on ARM64 (2026-02-24)

The full Chrome binary (`chrome-linux/chrome`) crashes with `SIGTRAP` on ARM64
in podman containers. The `chrome_crashpad_handler` subprocess cannot initialize,
and the crash is not fixable with `--no-sandbox`, `--shm-size`, or disabling
crashpad alone.

**Solution**: Use the headless shell binary instead. It works reliably in
containers. `launch.sh` finds it under `/ms-playwright/chromium_headless_shell-*/`
and passes it to the MCP as `--executable-path`.

The headless shell's path inside that directory changed with build 1254: from
`chrome-linux/headless_shell` to `chrome-headless-shell-linux-arm64/chrome-headless-shell`.
The old glob stopped matching, and the MCP silently fell back to full Chromium, which
crashes (verified 2026-11-12: full Chromium fails with "Target page, context or browser
has been closed", the headless shell works). `launch.sh` now checks both layouts and
warns when it finds neither. The Containerfile also replaces `chrome_crashpad_handler`
with a no-op, but that alone doesn't make full Chromium start.

Additionally, the MCP server (`@playwright/mcp@latest`) and the Python
`playwright` package may bundle different playwright-core versions that expect
different Chromium builds (e.g. 1208 vs 1212). The Containerfile installs
browsers for both versions to avoid "browser not installed" errors.

### MCP Server Registration (2026-02-24)

Claude Code overwrites `~/.claude.json` on exit, stripping manually-added
`mcpServers` entries. The `.mcp.json` project-level config requires a trust
dialog that doesn't persist reliably.

**Solution**: On every launch, `config/launch.sh` (inside the container)
rebuilds `~/.claude.json`. It starts from `config/claude.json`, merges in the
existing runtime state, and re-adds the servers from `config/mcp.json`. Playwright
is opt-in per project (`mosh playwright on`). `open-brain` is added only when
`OPENBRAIN_MCP_KEY` is set.

### Base Image (2026-02-24)

There is no official `anthropic/claude-code` Docker image. The Containerfile
uses `node:22` as the base and installs Claude Code with the native installer
(`curl -fsSL https://claude.ai/install.sh | bash`, as user `claude`, into
`~/.local`). The npm package is deprecated. Anthropic's devcontainer reference is at
https://github.com/anthropics/claude-code/tree/main/.devcontainer

### Config File Naming

Claude Code uses two separate config files:

- `~/.claude/settings.json` — permissions, model, env vars, effort level
- `~/.claude.json` — MCP servers, user state, onboarding, project data

MCP servers must go in `~/.claude.json`, NOT in `settings.json`. In the
container, these map to:

- `config/settings.json` → `/home/claude/.claude/settings.json` (copied)
- `config/claude.json` → `/home/claude/.claude.json` (used as the base of a merge; see above)

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

**Prevented since**: containers now carry a `mosh.version` label. On resume,
`mosh` refuses containers below `MOSH_MIN_COMPAT` (unlabeled ones count as v0),
warns about older ones, and refuses a container whose `/workspace` mounts differ
from the requested ones.

## File Inventory

| File/Dir | Purpose | Committed? |
|----------|---------|------------|
| `Containerfile` | Container image (node:22, Playwright, dcg, gh, Claude Code) | Yes |
| `.env.example` | Template for secrets | Yes |
| `.env` | Actual secrets | No (gitignored) |
| `mosh` | Host-side setup and launcher script (macOS bash 3.2) | Yes |
| `config/` | Repo-managed config, mounted at `/mosh-config` and synced in at launch | Yes |
| `config/launch.sh` | Runs inside the container: syncs config, rebuilds `~/.claude.json`, starts Claude in auto mode | Yes |
| `config/settings.json` | Permissions (`Read(.env)` denied), plugins, effort, status line | Yes |
| `config/claude.json` | Base for `~/.claude.json` (theme, onboarding, autoUpdates) | Yes |
| `config/mcp.json` | MCP server definitions (Playwright opt-in, open-brain) | Yes |
| `config/CLAUDE.md` | Container-specific global preferences | Yes |
| `config/agents/` | Custom subagents (`web-researcher.md`) | Yes |
| `config/uadf/` | UADF framework and skills (source of truth) | Yes |
| `config/default-plugins.txt` | Plugins installed in every new container | Yes |
| `config/certs/` | Extra CA certificates (NIST CA for the gateway) | Yes |
| `config/git-credential-helper` | Supplies the GitHub token to git from the environment | Yes |
| `config/gitignore_global`, `config/statusline.sh` | Global gitignore and status line | Yes |
| `CLAUDE.md` | Project instructions for Claude | Yes |
| `JOURNAL.md`, `JOURNAL_ARCHIVE.md`, `docs/adr/` | UADF handoffs and decision records | Yes |
| `docs/` | GitHub auth and volume backup guides, reference material | Yes |
| `README.md`, `SETUP-GUIDE.md`, `ROADMAP.md` | User-facing documentation | Yes |
| `tini-fix-brief.md` | Zombie-process investigation | Yes |
| `NOTES.md` | This file: ongoing project notes | Yes |
