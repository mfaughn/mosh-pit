# MoshPit Session Journal

## Session Handoff — 2026-03-20

### Completed This Session

- **Fixed file picker highlighting in containers**: `TERM` was defaulting to `xterm` (8 colors) inside the container, making Claude Code's autocomplete selection nearly invisible. Set `TERM=xterm-256color` in both the Containerfile and the mosh launcher (so it works before image rebuild). Commits: `6413c3a`.

- **Implemented automatic GitHub authentication**: When `GITHUB_PERSONAL_ACCESS_TOKEN` is set in `.env`, mosh now configures git inside the container to authenticate over HTTPS. Uses a standalone credential helper script (`config/git-credential-helper`) that reads the token from the environment at invocation time — nothing written to disk. Also adds `url.insteadOf` to transparently rewrite SSH remotes to HTTPS (inside the container only, host remotes untouched). Commits: `80e7ab7`, `8422401`.

- **Updated github-auth.md**: Replaced the original proposal doc with documentation of the implemented solution, including manual setup instructions for containers that predate the image rebuild. Commit: `c513af4`.

### Current State
- Branch: `main`
- Last checkpoint: `c513af4` — Update github-auth.md with implemented design and manual setup steps
- Tests: N/A (no test suite in this project)
- All changes pushed to remote

### Next Steps
1. Run `mosh build` on the host to rebuild the image with the new Containerfile changes (TERM env var, credential helper COPY)
2. Run `mosh fresh` for each project container to pick up the new image
3. Remove the `# TODO: remove after image rebuild` line for `-e TERM=xterm-256color` in the mosh launcher once the image is rebuilt
4. Remove any per-project git auth workarounds from `.claude-dev/provision.sh` files (e.g., Kelpie project mentioned in the original proposal)

### Open Questions / Blockers
- Items carried forward from SESSION-HANDOFF.md:
  - OAuth re-auth per project: each project gets its own named volume, so credentials don't carry between projects
  - UADF command naming: `/uadf:uadf-init` is redundant
  - HANDOFF.md is obsolete and can be deleted

### Relevant Context
- The inline shell function approach for the credential helper (`!f() { ... }; f`) does not work because git invokes credential helpers with `/bin/sh`, which is `dash` on Debian. Dash doesn't support the function syntax. The standalone script file approach avoids this entirely.
- The `url.insteadOf` approach is preferable to mutating remote URLs because it only affects `~/.gitconfig` in the named volume — it never modifies the bind-mounted project directory on the host.

## Session Handoff — 2026-03-24

### Completed This Session

- **Session auto-resume**: `mosh` now automatically resumes the last Claude Code session. After Claude exits, the session ID is saved to `~/.claude/last-session-id` (in the per-project named volume). On next launch, `--resume <id>` is passed to Claude Code. If resume fails, a noisy error tells the user to run `mosh new`. The `exec` was removed from the claude launch so the shell continues after exit to save state.

- **`mosh new` command**: Starts a fresh Claude Code session, skipping resume. Passes `MOSH_NEW_SESSION=1` env var into the container to suppress the `--resume` flag.

- **ROADMAP.md created**: Added a roadmap file for future features. First entry is worktree support with session resume, including architecture analysis (single container vs. separate containers per worktree — recommendation is Option B, separate containers).

- **Discussed Anthropic's autonomous work features**: Checkpoints, hooks, background tasks. Concluded no mosh-pit changes needed — these features work inside the container as-is. Checkpoints are complementary to `mosh save`/`mosh restore`.

### Current State
- Branch: `main` (1 unpushed commit from prior session: `c5212cc`)
- Uncommitted changes: `mosh` (session resume), `README.md` (updated commands), `ROADMAP.md` (new)
- Tests: N/A (no test suite)

### Next Steps
1. Review and commit the session resume changes
2. Push both unpushed commits to remote
3. Carry-forward from prior session: remove `TERM=xterm-256color` TODO line in mosh after image rebuild, delete obsolete `HANDOFF.md` and `SESSION-HANDOFF.md`

### Open Questions / Blockers
- The previous session's unpushed commit (`c5212cc` — dark mode, skip onboarding, raise effort level) should be pushed
- UADF command naming redundancy (`/uadf:uadf-init`) still unaddressed

### Relevant Context
- Session IDs are stored per-project automatically because each project container has its own named volume for `~/.claude/`. No explicit per-project keying is needed.
- The `--resume` flag reopens the exact same conversation with full history. This is different from `--continue` which starts a new conversation with context from the prior one.
- Worktree support is documented in ROADMAP.md but not yet implemented. Separate containers per worktree is the recommended approach.

## Session Handoff — 2026-03-24 12:30

### Completed This Session

- **Fixed broken quoting that prevented `mosh` from launching**: A single-quoted `echo` string on line 386 (inside the `SYNC_AND_LAUNCH` heredoc) contained literal single quotes that broke the outer `SYNC_AND_LAUNCH='...'` quoting. The host shell tried to execute `\033[1;33mmosh` as a command, producing `33mmosh: command not found`. Fix: removed the single quotes from the echo statement. Commit: `6fe329a`.

- **Pass ANTHROPIC_MODEL from host into container**: `ANTHROPIC_MODEL` (set in `~/.zshenv` on the host) was not being forwarded into containers, so Claude Code inside mosh sessions used the default model instead of the user's preferred `claude-opus-4-6@default[1m]`. Added conditional `-e ANTHROPIC_MODEL=...` to `COMMON_ARGS` in `build_common_args()`. Commit: `21201e4`.

- **Pushed all unpushed commits**: Three commits that were ahead of origin (`c5212cc`, `d261dbe`, and the two new fixes) are now pushed.

### Current State
- Branch: `main`
- Last checkpoint: `21201e4` — Pass ANTHROPIC_MODEL from host environment into container
- Tests: N/A (no test suite)
- All changes pushed to remote

### Next Steps
1. Carry-forward: remove `TERM=xterm-256color` TODO line in mosh after image rebuild
2. Carry-forward: delete obsolete `HANDOFF.md` and `SESSION-HANDOFF.md`
3. Carry-forward: UADF command naming redundancy (`/uadf:uadf-init`)
4. Consider whether other host env vars should also be passed through (e.g., `ANTHROPIC_DEFAULT_OPUS_MODEL`, `ANTHROPIC_DEFAULT_SONNET_MODEL`)

### Open Questions / Blockers
- None

### Relevant Context
- The quoting bug was introduced in commit `d261dbe` (session auto-resume). Any time code is added inside the `SYNC_AND_LAUNCH='...'` single-quoted block, single quotes must use the `'"'"'` escape pattern or be avoided entirely.
- `--env-file` does not expand shell variables or handle bare variable names when the file is also `source`d by bash (line 138), so passing host env vars requires explicit `-e` flags in COMMON_ARGS.

## Session Handoff — 2026-04-01

### Completed This Session

- **Status line script syncing into containers**: Added `config/statusline.sh` (shows model, context %, duration, branch) and configured it to sync into `~/.claude/` on every container launch. Added `statusLine` hook to `config/settings.json` pointing to the container path `/home/claude/.claude/statusline.sh`. The host can symlink `~/.claude/statusline.sh` to the repo copy for single-source-of-truth. Commit: `0188e8b`.

- **Fixed provisioning for multi-project containers**: Provision scripts and plugin files were only checked for the first project directory, and the container-side path was hardcoded to `/workspace/.claude-dev/provision.sh`. In multi-project mode, projects mount at `/workspace/<dirname>/`. Now iterates all mounted projects and computes the correct container path for each. Commit: `2a23049`.

- **Resolved shell variables in .env**: Podman's `--env-file` reads values literally without shell expansion, so entries like `GITHUB_PERSONAL_ACCESS_TOKEN=$GITHUB_TOKEN` were passed as the literal string `$GITHUB_TOKEN`. Now generates a resolved temp file after sourcing `.env` (which expands `$VAR` references using the host environment). Only variables listed in `.env` are included — the full host environment is not leaked. Commit: `e281327`.

- **Auto-update Claude Code on new containers**: New containers now run `npm install -g @anthropic-ai/claude-code@latest` before provisioning, so they always start with the current version regardless of base image age. Also fixed `install_plugins` — the `--yes` flag never existed in `claude plugin install`, so plugin installation had been silently failing in all new containers. Commit: `7bf0fae`.

### Current State
- Branch: `main`
- Last checkpoint: `7bf0fae` — Auto-update Claude Code on new containers and fix plugin install
- Tests: N/A (no test suite)
- All changes pushed to remote

### Next Steps
1. Carry-forward: remove `TERM=xterm-256color` TODO line in mosh after image rebuild
2. Carry-forward: delete obsolete `HANDOFF.md` and `SESSION-HANDOFF.md`
3. Carry-forward: UADF command naming redundancy (`/uadf:uadf-init`)
4. Run `mosh fresh` for existing project containers to pick up all fixes (env resolution, plugin install, auto-update)
5. Consider adding `--no-cache` option to `mosh build` for forcing fresh image builds

### Open Questions / Blockers
- None

### Relevant Context
- Env vars are baked into containers at `podman run` time. Resuming a container (`mosh`) does NOT re-read `.env`. Changes to `.env` require `mosh fresh` to take effect.
- The `set -u` (nounset) flag in the mosh script will crash if `.env` references a variable (e.g., `HL7_JIRA=$HL7_JIRA`) that isn't exported in the host shell. This is intentional — it's a loud signal that `~/.zshenv` needs to be sourced rather than silently creating a container with missing env vars.
- The base image caches the `npm install -g @anthropic-ai/claude-code@latest` layer. Rebuilding with `mosh build` won't update Claude Code unless `--no-cache` is used. The auto-update step on `mosh fresh` makes this acceptable.
- Plugins installed in one container's named volume don't carry to other projects' containers. Each needs its own plugin installation (now handled automatically via `default-plugins.txt`).
- Claude Code reads sensitive file contents (like `.env`) into its full context window. There is no selective exclusion mechanism.

## Session Handoff — 2026-04-28

### Completed This Session

- **Skipped onboarding on fresh containers**: `~/.claude.json` lives outside the named volume and was wiped on `mosh fresh`, triggering onboarding every time. Now syncs `config/claude.json` as the base (theme: dark, hasCompletedOnboarding: true, autoUpdates: false), merges existing runtime state, then re-injects MCP servers. Commit: `98a0079`.

- **Updated README**: Rewritten to cover all three auth modes (OAuth, API key, Vertex AI) without emphasizing any one. Added sections for env var resolution, provisioning, project-specific config. Commit: `d2c128c`.

- **Switched from npm to native installer**: Claude Code deprecated the npm install method. Containerfile now uses `curl -fsSL https://claude.ai/install.sh | bash` as user `claude` (installs to `~/.local/bin/`). Updated auto-update on new containers and `mosh update` to use the native installer. Added `~/.local/bin` to PATH in both Containerfile and SYNC_AND_LAUNCH. Commit: `4369ae2`.

- **Upgraded base image to node:22 LTS**: Node 20 reaches end-of-life April 2026. Node 22 is current LTS (through April 2027) and ships with newer npm, silencing update notices. Node is only needed for Playwright MCP now. Commit: `d6e060c`.

- **Added NPM security settings and global gitignore**: Set `NPM_CONFIG_IGNORE_SCRIPTS=true` to block malicious postinstall scripts, `NPM_CONFIG_AUDIT=true`, `NPM_CONFIG_FUND=false`. Added `config/gitignore_global` synced on every launch to prevent accidentally committing common artifacts. Inspired by trailofbits/claude-code-devcontainer. Commit: `f858cd5`.

- **Compared with trailofbits/claude-code-devcontainer**: Analyzed their security-audit-focused approach. Key differences: they target VS Code devcontainers for untrusted code review with optional network isolation; mosh-pit is a standalone CLI with better workflow ergonomics (auto-resume, multi-project, snapshots, config sync). Adopted their NPM security settings and global gitignore ideas.

### Current State
- Branch: `main`
- Last checkpoint: `f858cd5` — Add NPM security settings and global gitignore
- Tests: N/A (no test suite)
- All changes pushed to remote

### Next Steps
1. Run `mosh build --no-cache` on host to rebuild image with native installer and node:22
2. Run `mosh fresh` for existing containers to pick up all fixes
3. Investigate the "missing file" message the user sees on mosh startup (scrolls away before resume)
4. Carry-forward: remove `TERM=xterm-256color` TODO line in mosh after image rebuild
5. Carry-forward: delete obsolete `HANDOFF.md` and `SESSION-HANDOFF.md`
6. Carry-forward: UADF command naming redundancy (`/uadf:uadf-init`)
7. Consider adding `ast-grep` to base image (AST-based code search, useful for Claude Code)

### Open Questions / Blockers
- User reported a "missing file" message on mosh startup that disappears after session resume. Could be related to Playwright chromium path (config/claude.json points to `chromium_headless_shell-1208` but newer builds install v1217), or session resume attempting a file that doesn't exist. Needs investigation.

### Relevant Context
- The native Claude Code installer installs to `~/.local/bin/claude`. This is in the container's writable layer (not the named volume), so on `mosh fresh` the binary is gone but gets reinstalled by the auto-update step.
- NPM security env vars (`NPM_CONFIG_IGNORE_SCRIPTS`) are baked into containers at creation time. Existing containers need `mosh fresh` to pick them up. The global gitignore syncs on every launch (no `mosh fresh` needed).
- The base image caches layers. `mosh build` without `--no-cache` won't pull the new node:22 base or re-run the native installer. First rebuild after this session should use `--no-cache`.
- `config/claude.json` Playwright MCP executable path may need updating to match the chromium version installed by the current Containerfile build.

## Session Handoff — 2026-05-01

### Completed This Session

- **Cleanup carry-forwards**: Deleted obsolete `HANDOFF.md` and `SESSION-HANDOFF.md`. Added `host_claude_dir` to `.gitignore` (host-side symlink to `/Users/mrf/.claude` that landed in the repo). Removed redundant `-e TERM=xterm-256color` line in `mosh` (Containerfile already bakes it in). Commit: `8c56e2a`.

- **Added CLI tools to base image**: `gh` (GitHub CLI, via official apt repo), `ripgrep`, `fd-find` (symlinked to `fd`), `shellcheck` via apt; `@ast-grep/cli` via npm alongside `@playwright/mcp`. Documented the available tool set in `config/CLAUDE.md` so Claude reaches for them over slower defaults. Commit: `8620167`.

- **Fixed Playwright chromium path drift**: The hardcoded `/ms-playwright/chromium_headless_shell-1208/...` path in `config/mcp.json` and `config/claude.json` went stale every few months as Playwright updated its bundled Chromium, producing a "missing file" error that scrolled off-screen during session resume on freshly built containers. Removed the hardcoded `--executable-path` from both files; the launcher's python sync now globs `/ms-playwright/chromium_headless_shell-*/chrome-linux/headless_shell` and appends the newest as `--executable-path` at launch. Also dropped the unused `mcpServers` section from `config/claude.json` (the python sync overwrites it from `mcp.json` regardless). Commit: `481a3a5`.

- **Added destructive_command_guard (dcg), opt-in per project**: Container ships `dcg` in `/usr/local/bin/` (installed via the official `install.sh` with `--no-configure --system` — binary only, no hooks wired by default). New `mosh dcg [on|off|status]` command toggles a per-project sentinel `~/.claude/.dcg-enabled` in the project's named volume by spinning up a one-off container against the volume. The launcher's settings.json sync conditionally injects the PreToolUse Bash hook based on the sentinel. Commit: `6448cfc`.

### Current State
- Branch: `main`
- Last checkpoint: `6448cfc` — Add destructive_command_guard, opt-in per project via mosh dcg
- Tests: N/A (no test suite). Verified bash + embedded python syntax, JSON validity, end-to-end sync simulation, dcg hook injection idempotency.
- All changes pushed to remote.

### Next Steps
1. `mosh build --no-cache` on host to rebuild image with new tools (gh, ast-grep, ripgrep, fd, shellcheck) and dcg binary, plus the node:22 + native-installer changes from the prior session that may not have been picked up yet.
2. `mosh fresh` for existing project containers to pick up the new image.
3. mosh-script changes (chromium path resolution, TERM removal, `mosh dcg` command) take effect on next `mosh` launch — no rebuild needed for those.
4. Decide whether the carry-forward "UADF command naming redundancy (`/uadf:uadf-init`)" is worth addressing.

### Open Questions / Blockers
- None. The dcg toggle requires `/exit` + `mosh` to take effect (settings.json is only synced at launch, and Claude Code reads it at startup). User confirmed this is acceptable. A future enhancement could add an in-session slash command if the friction becomes annoying.

### Addendum — Playwright MCP made opt-in (same session)

After the initial handoff was written, user noticed two Playwright MCP entries in `/mcp` both showing failed: one from our `config/mcp.json` (with `--headless --no-sandbox` and the dynamically-resolved chromium path), and one from the official `playwright@claude-plugins-official` plugin (bare `npx @playwright/mcp@latest`, no flags — chromium can't run as non-root in the container without `--no-sandbox`). The two collide on the server name "playwright" so both show as failed.

Fix:
- Removed `playwright@claude-plugins-official` from `enabledPlugins` in `config/settings.json`.
- Removed it from `config/default-plugins.txt` so new containers no longer install it (otherwise `claude plugin install` re-enables it on `mosh fresh`).
- Made the user-config Playwright MCP opt-in: launcher python sync drops the `playwright` server from `~/.claude.json` unless `~/.claude/.playwright-enabled` exists in the named volume.
- Added `mosh playwright [on|off|status]` mirroring `mosh dcg`. Same persistence model — sentinel lives in the named volume, survives `mosh fresh`, only `podman volume rm` clears it.

Commit: `4d09ade` (playwright opt-in), then a follow-up commit dropping it from default-plugins.txt.

### Updated state (after Playwright work)
- Branch: `main`
- All changes pushed.
- Default for new projects: no Playwright MCP, no Playwright plugin. Browser automation requires explicit `mosh playwright on` per project.

### What gets loaded into mosh containers (reference)

**Plugins** (installed by `claude plugin install` from `config/default-plugins.txt`, enabled via `enabledPlugins` in `config/settings.json`):
- `code-review`, `code-simplifier`, `ralph-loop`, `commit-commands`, `frontend-design` — all from `@claude-plugins-official`
- `playwright` — opt-in per project via `mosh playwright on` (not in default-plugins.txt anymore)
- Per-project: anything in `<project>/.claude-dev/plugins.txt`

**MCP servers** (from `config/mcp.json`, injected into `~/.claude.json` by launcher sync):
- `playwright` — only when `~/.claude/.playwright-enabled` sentinel exists
- `open-brain` — only when `OPENBRAIN_MCP_KEY` env var is set

**Agents** (synced from `config/agents/` to `~/.claude/agents/`):
- `web-researcher` — used for web searches since the model has WebSearch blocked

**Hooks** (conditionally injected into `~/.claude/settings.json` by launcher sync):
- `dcg` PreToolUse on Bash — only when `~/.claude/.dcg-enabled` sentinel exists

**Commands** (bind-mounted read-only from host's `~/.claude/commands/`):
- Whatever the user has on the host — single source of truth, no duplication

**Templates** (synced from `config/templates/` to `~/.claude/templates/`):
- `architecture.md`, `claudemd.md`, `lessons.md`, `spec.md`, `tasks.md`

**UADF skill bundle** (synced from `config/uadf/` to `~/.claude/uadf/`):
- `framework.md` plus `templates/` — referenced by the `/uadf-*` skills installed via the UADF plugin/marketplace

### Relevant Context
- **dcg rationale**: mosh-pit's container boundary does NOT protect `/workspace` (it's a bind mount), so `rm -rf /workspace`, `git reset --hard`, `git push --force`, etc. really can lose work. dcg is opt-in rather than default-on because false positives would add daily friction against `--dangerously-skip-permissions`, which is the whole point of mosh.
- **dcg state model**: The sentinel is per-project (lives in the project's named volume `${container_name}-claude-home`), so toggling it for one project does not affect others. The hook gets injected by the launcher's python sync, which means `mosh dcg on` followed by `/exit` + `mosh` is the canonical activation flow.
- **dcg install method**: Used the official `install.sh` with `--no-configure --system`. Auto-detects platform (linux-aarch64 here), downloads the prebuilt binary from GitHub releases with checksum verification, installs to `/usr/local/bin/`. `--no-configure` skips all the auto-hook wiring (Claude Code, Gemini CLI, Cursor, etc.) so we control hook state ourselves via the sentinel.
- **chromium path resolution**: The glob-based approach picks the lexically-newest version, which works for the foreseeable future since Playwright revisions monotonically increase from the current 4-digit values. The container at this point has both `1208` and `1217` installed because rebuilds at different times added each; a fresh build today would only have the newest.
- **Available tools in CLAUDE.md**: `config/CLAUDE.md` now documents `gh`, `rg`, `fd`, `ast-grep`, `shellcheck`, `jq` so Claude prefers them over slower defaults like `find`/`grep`. Claude figures out tools from PATH on its own, but explicit documentation makes it more likely to reach for the less-famous ones (especially `ast-grep`).

---

## Session Handoff — 2026-09-10

### Completed This Session

- **Extracted the container launch script**: The ~150-line config-sync-and-launch routine lived as a single-quoted bash string (`SYNC_AND_LAUNCH`) inside `mosh`, which meant shellcheck and editors couldn't see it and `ps aux` printed the whole thing on one line per running container. Moved it to `config/launch.sh`, executed as `bash /mosh-config/launch.sh`. Because `config/` is already bind-mounted read-only at `/mosh-config`, existing containers pick it up with no rebuild. Also converted `claude $CLAUDE_ARGS` (unquoted, word-split) to a proper array, and added a `launch.sh` existence check next to the `settings.json` one in setup. Commit: `639bace`.

- **Migrated Claude auth from Vertex AI to the NIST LiteLLM gateway**: `.env` now references gateway variables from the host shell instead of hardcoding Vertex project/region. Added a gateway auth-mode branch that prints the resolved endpoint at startup, plus a warning when a key is set without a base URL (which would silently send a gateway key to `api.anthropic.com`). Removed the `"model"` pin and stale `ANTHROPIC_DEFAULT_OPUS_MODEL` from `config/settings.json` — those names don't exist on the gateway. Deleted `compose.yaml` (nothing invoked it; `COMPOSE_FILE` was assigned and never read; it hardcoded `CLAUDE_CODE_USE_VERTEX: "1"`). Commit: `639bace`.

- **Trusted the internal NIST CA inside the container**: Claude Code failed with "SSL certificate verification failed" against the gateway. `launch.sh` now trusts any `*.pem` in `/mosh-config/certs`. Commit: `271c292`.

- **Stopped a stale `ANTHROPIC_MODEL` from overriding the tier aliases**: A leftover host export pinned `claude-opus-5@default[1m]`, producing a gateway 403 whose message misleadingly suggests running `/login`. Added `ANTHROPIC_MODEL` to both unset lists so only `.env` can set it. Also quoted `.env` references as `${VAR:-}` — a bug introduced earlier the same session, where an unset host variable would abort `mosh` under `set -u` with a bare "unbound variable". Commit: `30d5cac`.

- **Read host config from a pristine shell at launch**: Editing `~/.zshenv` then launching from the same terminal used that terminal's stale values, forcing an exit/source/relaunch cycle. `mosh` now probes a fresh shell under `env -i`. The variable list is scraped from the `${NAME:-}` references in `.env` rather than hardcoded, so it can't drift. Commit: `5ae37be`.

### Current State
- Branch: `main`
- Last checkpoint: `5ae37be` — Read host config from a pristine shell at launch
- Tests: N/A (no test suite). Verified bash syntax and shellcheck on `mosh` and `config/launch.sh` (only pre-existing SC1090/SC2155/SC2015/SC2012 remain), JSON validity, and simulated env resolution against the real `.env` including stale-value and unbound-variable cases. CA chain verified against the live gateway (curl and Node both reach it; github.com still verifies).
- All changes pushed to remote.
- Gateway confirmed working end to end by the user: arithmetic returns and the Anthropic model env vars look correct inside the container.

### Next Steps
1. Exercise the tier aliases individually — `/model opus`, `/model sonnet`, `/fast`, and a `web-researcher` subagent call. A successful prompt only proves the *default* model resolves; a typo surviving in `ANTHROPIC_DEFAULT_SONNET_MODEL` or `_HAIKU_MODEL` stays invisible until `/fast` or a subagent runs.
2. Run `mosh fresh` on the remaining project containers to pick up the gateway env.
3. Carry-forward, still undecided: whether the UADF command naming redundancy (`/uadf:uadf-init`) is worth addressing.

### Open Questions / Blockers
- None blocking.

### Relevant Context — things that cost time this session

- **Auth env is baked in at container creation, config files are not.** `--env-file` is evaluated at `podman run`, so changing an environment variable requires `mosh fresh` (recreate), not just `mosh` (start + exec). By contrast `config/` is bind-mounted read-only, so `settings.json`, `launch.sh` and the CA certs apply on the *next launch* with no rebuild and no `fresh`. Knowing which of the two a change falls under saves a lot of guessing. `MOSH_VERSION` was bumped to 3 so stale containers warn.

- **An image rebuild (`mosh build`) is never needed for configuration.** The Containerfile copies exactly one file (`config/git-credential-helper`). Everything else arrives through the `/mosh-config` mount. This contradicted the premise of the migration brief, which assumed settings were baked into the image.

- **`source ~/.zshenv` cannot unset a variable you deleted from it.** Sourcing only re-runs the exports still present in the file, so a deleted line leaves the old value live in that shell. Only a new shell — or the `env -i` probe added in `5ae37be` — reflects deletions. This is distinct from *editing* a value, where sourcing does work; the two failure modes look identical from the outside.

- **The container diverges from the host on TLS.** macOS trusts `NISTIssuingCA03` via Keychain, so host-native Claude Code reaches the gateway fine while the container fails. Worse, the gateway sends only its leaf certificate and omits the intermediate (openssl verify error 21, not 20), so trusting the root alone is insufficient — the bundle must carry both. Fingerprints and regeneration steps are in `config/certs/README.md`; the root fingerprint was confirmed against the host Keychain.

- **`ANTHROPIC_MODEL` and `ANTHROPIC_DEFAULT_*_MODEL` do different jobs.** The former pins one model; the latter three define what "opus"/"sonnet"/"haiku" resolve to, which is what `/model`, `/fast`, `opusplan` and subagent selection depend on. A stale pin silently defeats the aliases. This caused confusion three separate times in one day, hence the unset.

- **`config/settings.json` is committed**, so the API key can never live there. The key is referenced from `.env` as `$NIST_LITELLM_KEY` — a name distinct from `ANTHROPIC_API_KEY` specifically because `mosh` unsets `ANTHROPIC_API_KEY` before reading `.env`; a self-reference would resolve to empty. The real value lives in `~/.zshenv`, which also serves host-native Claude Code, so there is one source of truth for both.

## Session Handoff — 2026-09-14 18:38

### Completed This Session

- **Stopped Claude Code asking to approve the gateway API key on every new project**: the prompt ("Detected a custom API key in your environment", with *No* marked recommended) persists its answer in `~/.claude.json` under `customApiKeyResponses.approved`, keyed on the **last 20 characters** of the key. That file lives in the per-project named volume and is seeded from `config/claude.json`, which carries no approval — so each new project asked again. `config/launch.sh` now seeds the approval during its existing `claude.json` sync, computed at launch from `$ANTHROPIC_API_KEY` so no key material is committed. A stale rejection of the same key is cleared, since the key can only come from `.env` and a "No" leaves the container with no working auth rather than expressing a preference. Commit: `e51e029`.

- **Made Fable selectable in `/model`**: added `ANTHROPIC_DEFAULT_FABLE_MODEL` to the tier aliases. Documented in `.env.example` and `mosh --help`; the `${NAME:-}` reference line lives in the gitignored `.env`. Commit: `25db462`.

- **Resolved the long-standing UADF naming carry-forward**: user's call — `/uadf:uadf-init` is a nothingburger, not worth changing. Deliberately dropped, not deferred. Do not re-raise.

### Current State
- Branch: `main`
- Last checkpoint: `25db462` — Carry ANTHROPIC_DEFAULT_FABLE_MODEL into containers
- Tests: N/A (no test suite). `bash -n` and shellcheck clean on `mosh` and `config/launch.sh` (same 3 pre-existing infos as HEAD, no new findings); the launcher's API-key injection was simulated against six scenarios — fresh volume, repeat launches, stale rejection, rotated key, absent key, and preservation of existing runtime state.
- All changes pushed to remote.
- Verified live by the user: Fable appears in `/model` and is selectable after `mosh fresh`.

### Next Steps
1. Nothing outstanding in this repo. Fable is blocked upstream (below), not by anything here.
2. Still open from the prior session: exercise `/model sonnet`, `/fast` and a `web-researcher` subagent call to prove the Sonnet and Haiku aliases resolve. Opus and Fable are now both confirmed; a typo in the other two stays invisible until something actually routes to them.
3. Still open from the prior session: `mosh fresh` on the remaining project containers to pick up the gateway env — now also required for the API-key approval and Fable.

### Open Questions / Blockers

- **Fable returns HTTP 429 from the gateway.** Not a local problem, and not LiteLLM's budget either — the upstream refusal is a Google Cloud one:
  `Quota exceeded for aiplatform.googleapis.com/us_multi_region_online_prediction_requests_per_base_model with base model: anthropic-claude-fable` / `RESOURCE_EXHAUSTED`.
  Three back-to-back attempts all failed, which leans toward quota provisioned at or near zero rather than momentary contention — though rapid retries cannot fully separate the two, since a per-minute limit fails all three either way. Opus 5 returned HTTP 200 through the same key and gateway in the same test, so the path is healthy. Fixing it requires a Vertex AI quota-increase request for base model `anthropic-claude-fable` in the US multi-region, filed by whoever owns the GCP project behind `trill.nist.gov`. **Leave the alias configured** — Fable starts working the day the quota is raised, with no change on this side.

### Relevant Context — things that cost time this session

- **The NIST gateway is itself backed by Vertex AI.** Responses come back with `msg_vrtx_...` ids. The migration in `639bace` moved off *direct* Vertex auth, but Vertex is still underneath — which is why a Google quota error surfaces through an Anthropic-shaped API. Expect Google-flavoured failures to keep appearing despite the gateway.

- **Fable is gated differently from the other three tiers.** `isFableAvailable()` in the CLI runs an entitlement probe against the first-party API, which a gateway cannot answer, so Fable is simply omitted from `/model` — no error, no hint. Every branch of that function short-circuits to true when `ANTHROPIC_DEFAULT_FABLE_MODEL` is set. The variable does a second job too: the family check looks for a leading `claude-fable-`, which the gateway's `itl-airms/`-prefixed id fails, so the alias is also what makes the CLI classify the model as Fable at all.

- **The launcher's `${NAME:-}` scrape is what carries a host export across.** The `env -i` probe added in `5ae37be` reads variable *names* out of `.env`. A host export with no corresponding reference line in `.env` never reaches the container — which is exactly why Fable stayed hidden even though the host export had been set for some time. Adding a tier alias is therefore always a two-sided change: the export on the host, the reference line in `.env`.

- **`.env` is gitignored**, so reference lines added there are local-only. `.env.example` is the sole record a fresh clone gets. Its example block had also drifted (it still showed `claude-opus-4-6` while the live alias was `claude-opus-5`); corrected this session.

- **The error message for an unapproved API key is misleading.** Declining the prompt leaves the container with no auth at all, since `mosh` unsets host `ANTHROPIC_API_KEY` and `.env` is the only source. "No" is never the right answer in this setup, despite being the recommended option.

---

## Session Handoff — 2026-09-16 14:19

### >>> START HERE — manual verification still pending <<<

The port feature is code-complete and statically verified, but everything needing a
real podman was never run. **Do these before committing or merging
`feat/port-allocation`.** Each has an explicit pass condition.

Note `mosh fresh` ends by attaching Claude Code, so the terminal stays busy until
`/exit` — tests needing two projects at once need two terminals.

**Test 1 — ports publish and actually serve.** Terminal 1, any project:

```bash
mosh fresh
```

Watch the launch output for two things: the host's `[mosh] Ports (slot N):` table, and
`[mosh] Serving: http://localhost:<base> -> container :3000` printed last, just before
Claude starts. Then inside that Claude session:

```bash
python3 -m http.server "$MOSH_PORT" --bind 0.0.0.0 &
```

Open `http://localhost:<base>` in the browser.
**Pass:** the directory listing loads.

**Test 2 — no collision between two projects.** This is the property the whole design
exists for. Leave Test 1 serving, and in terminal 2 from a *different* project:

```bash
mosh fresh
```

Start a server inside it the same way, and open both host URLs.
**Pass:** the two bases differ, and both pages load at the same time, each showing its
own project's files.

**Test 3 — `mosh fresh` preserves the slot.** Terminal 3, from the Test 1 project:

```bash
mosh ports          # note the slot
```

`/exit` that session, `mosh fresh` again, then `mosh ports` once more.
**Pass:** same slot, same base as before.

**Test 4 — the loopback trap is real.** Inside a container, bind the wrong interface:

```bash
python3 -m http.server "$MOSH_PORT" --bind 127.0.0.1 &
```

**Pass:** the host URL refuses the connection. This is the failure mode
`config/CLAUDE.md` warns about; confirming it proves the warning earns its place.

**Test 5 — registry inspection and reclamation.** From the host:

```bash
mosh ports list
```

**Pass:** every launched project is listed `active`; a project whose container was
removed shows `(stale — no container)`. Delete a stale line from `.ports`, launch a
brand-new project, and confirm it claims that freed slot.

**Also expect:** launching a not-yet-freshed container warns it was made by mosh v3
*and* that it publishes no ports. That is correct — v3 containers run fine, they just
have no ports until recreated. They should show **no** `Serving:` line.


### Completed This Session

- **Added per-container host port allocation** so each mosh container can serve web
  content viewable at `http://localhost:<port>` on the host, with no possibility of
  two containers mapping the same host port. Containers published no ports at all
  before this — there was no `-p` anywhere in `mosh`.

  Design, settled with the user up front:
  - **Slot-based registry.** Each project gets a slot; host base = `20000 + slot*10`.
    Slots live in `.ports` (gitignored, beside `.env`), keyed on container name.
    Lowest unused slot wins. Chosen over a hash of the container name, which gives
    only a *probability* of uniqueness (~18% collision odds at 20 projects) and
    records nothing when a collision forces a shift.
  - **Curated container-side ports**, identical in every container:
    3000, 4000, 5173, 8000, 8080, 8888, 9000 → host `base+0..6`. Common dev-server
    defaults, so most tools need no `--port` flag. Stride is 10 with only 7 published:
    the 3 spares let an eighth port be added later without renumbering anything.
  - **Loopback-only binding** (`127.0.0.1:`). These dev servers have no auth in front
    of them, so they stay off the LAN. An opt-in LAN toggle mirroring `mosh dcg` was
    considered and deliberately not built.
  - **Reclamation is a hand edit.** Delete a line from `.ports` to return the slot to
    the pool. No `prune` subcommand — this keeps a destructive code path out of the
    script entirely. `mosh ports list` marks entries whose container is gone as
    `(stale)` so it is obvious which lines are safe to remove.

  New: `mosh ports` (this project's map) and `mosh ports list` (all projects). Both
  are strictly read-only — inspecting never allocates a slot.

- **Deleted a stale two-line comment at the end of `.gitignore`** claiming
  `config/claude.json` runtime rewrites were ignored. Investigated before removing:
  the rule it described was never actually written, and it would not have worked
  anyway — `.gitignore` has no effect on tracked files, and that intent needs
  `git update-index --skip-worktree`. It was describing the pre-`ba31666` architecture
  when `config/` was the container's writable `~/.claude`; today `/mosh-config` is
  mounted `:ro` so a container cannot write there at all.

- **Created `docs/adr/`** and the repo's first ADR,
  `0001-per-container-host-port-allocation.md`, recording registry-vs-hash,
  curated-vs-contiguous ports, and loopback-vs-LAN with the alternatives considered.

### Current State
- Branch: `feat/port-allocation`. **[Corrected 2026-09-16 18:50: this entry originally
  read "not merged, nothing committed". That was written minutes before the work was
  actually committed — `a8e283f`, `83d1e79` and this journal update `b507e3a` all landed
  at 14:30 the same day. The branch was merged to `main` later that day.]**
- Files touched: `mosh`, `config/launch.sh`, `config/CLAUDE.md`, `README.md`,
  `.gitignore`, plus new `docs/adr/0001-per-container-host-port-allocation.md`.
- `MOSH_VERSION` 3 → 4, with a version-history entry. Existing containers warn on
  launch and gain ports only after `mosh fresh`.
- Tests: no suite in this repo. `bash -n` clean on `mosh` and `config/launch.sh`;
  shellcheck output **matches HEAD exactly** on both (an SC2013 introduced by the
  first draft was fixed). Allocation logic exercised against a harness: sequential
  allocation, idempotent re-lookup, slot reclamation after a hand delete, 20
  concurrent allocations yielding 20 unique slots with no leftover lock,
  registry-full refusal writing nothing, and correct `-p` args. Real `./mosh ports`,
  `ports list`, `ports bogus` and `help` runs against a stub podman.
- **Not yet verified — needs podman on the host:** the actual `podman run` with `-p`
  flags, `mosh fresh` preserving a slot, two containers serving simultaneously, and
  the loopback negative test.

### Next Steps
1. **Run Tests 1-5 in the START HERE block at the top of this handoff.** Not repeated
   here on purpose — one copy, so the two cannot drift apart.
2. Commit. User asked to consider splitting the `.gitignore` comment deletion from the
   port feature — decide one commit or two, then merge to `main`.
3. Carry-forward from prior sessions, still open: exercise `/model sonnet`, `/fast`
   and a `web-researcher` subagent call to prove the Sonnet and Haiku aliases resolve.
   Opus and Fable are confirmed; a typo in the other two stays invisible until
   something routes to them.
4. Carry-forward: `mosh fresh` on remaining project containers for the gateway env,
   the API-key approval, and Fable — now also for ports.

### Open Questions / Blockers
- None for the port work.
- Still blocked upstream: Fable returns HTTP 429 from the gateway (Google Cloud quota
  `RESOURCE_EXHAUSTED` on base model `anthropic-claude-fable`). Leave the alias
  configured; it starts working the day the quota is raised.

### Relevant Context — things worth not rediscovering

- **Podman fixes port mappings at container-creation time.** A mapping cannot be added
  to a running container, which is why a whole block is pre-published whether used or
  not, and why an eighth port would mean `mosh fresh`. Ports belong to the same
  category as `--env-file`: baked in at creation, unlike `config/`, which is
  bind-mounted and applies at next launch.

- **`.ports` is mosh's first host-side shared state file.** The `dcg`/`playwright`
  precedent stores per-project sentinels inside the project's own volume, which
  structurally cannot work here: detecting a collision requires seeing every project
  at once, and a per-project volume only ever sees itself.

- **A v3 container under v4 mosh runs, by design.** `MOSH_MIN_COMPAT` stayed at 1, so
  only pre-v1 containers are hard-blocked; v3 warns and proceeds. The v3→v4 change is
  purely additive (publishing ports), so nothing about an existing container is broken
  by the new script — it simply cannot serve web content until `mosh fresh`. Raising
  MIN_COMPAT to 4 would have hard-failed every existing container across every project
  for the sake of an additive feature.

- **Three bugs that only surfaced by running the code.** The third was caught by the
  user asking whether a v3 container really was safe under v4 mosh:
  (a) `info` inside `ports_registry_init` wrote to stdout, which `$(port_slot_for …)`
  captures — the first-ever launch would have taken the message *plus* the number as
  its slot. Any human-facing output from a function whose stdout is a return value has
  to go to stderr. (b) A refused allocation was appended to the registry *before* the
  range check, so a full registry would record an unusable line that every later
  launch looked up and refused again — permanently poisoned. Validate before writing.
  (c) The resume path warned "this container publishes no ports" for a pre-v4
  container but still passed `MOSH_PORT*` on the exec, so `launch.sh` printed
  `Serving: http://localhost:<base>` and `config/CLAUDE.md` told Claude that port was
  reachable — directly contradicting the warning three lines above. The port env is
  now blanked on that path. Note it is blanked to a one-element array rather than
  `()`, because `"${empty[@]}"` under `set -u` errors on bash 3.2.

- **The launch banner scrolls away on a new container.** Claude Code update,
  provisioning and plugin installs all print after the host's port table, so
  `launch.sh` repeats the essentials immediately before `claude` starts. That is why
  the port info is printed twice rather than once.

- **`mosh fresh` cannot be followed by `mosh ports` in the same terminal** — `fresh`
  ends by attaching Claude Code, so the terminal is occupied until `/exit`, at which
  point the container stops. Use a second terminal, or just read the two port lines
  printed during launch. (Caught by the user; the first verification sequence written
  this session was wrong.)

- **Resume-path gating uses the `mosh.version` label, not `podman inspect` of port
  bindings.** The label is already read a few lines earlier and cannot misreport
  because of a runtime-specific inspect field name; a bad Go template would have
  silently produced a false "publishes no ports" warning on a container that has them.

- **Bash 3.2 compatibility matters.** The shebang is `#!/usr/bin/env bash`, which on
  macOS may resolve to `/bin/bash` 3.2, where `"${arr[@]}"` on an empty array under
  `set -u` errors. New code avoids empty-array expansion and associative arrays.

- **The `.ports` lock is a `mkdir` mutex** with a trap on `EXIT INT TERM`. `mkdir` is
  atomic on both macOS and Linux. Verified with 20 parallel allocations.

## Session Handoff — 2026-09-16 18:50

### >>> START HERE — still unverified <<<

The port feature is **merged to `main`**, but three checks from the previous handoff's
checklist never ran. None blocks use of the feature; each is cheap to close
opportunistically. Do not re-run Tests 1, 2, 4 or 5a — they passed this session.

**Test 3 — `mosh fresh` preserves the slot.** From the mosh-pit project:

```bash
mosh ports          # note the slot
```

`/exit`, `mosh fresh`, then `mosh ports` from a *second* terminal (the first stays
occupied until Claude exits, and exiting stops the container).
**Pass:** same slot, same base. Already covered by last session's allocation harness
(idempotent re-lookup), so this is real-environment confirmation, not new ground.

**Test 5b — slot reclamation.** Delete a line from `.ports` whose container is gone,
launch a brand-new project, confirm it claims the freed slot. Needs a container to
actually be missing — run it the next time one genuinely goes away.

**The `(stale — no container)` branch of `mosh ports list`.** Never executed: all four
registered containers were active. Same precondition as Test 5b, so they close together.

### Completed This Session

- **Ran the port verification checklist. Four of five tests pass.**
  - **Test 1 (ports publish and serve):** pass. Server on `0.0.0.0:$MOSH_PORT` in the
    mosh-pit container, reachable at `http://localhost:20020` on the host.
  - **Test 2 (no collision between projects):** pass — the property the whole design
    exists for. `cc-v2ig` (20010) and `cc-mosh-pit` (20020) served simultaneously, each
    its own files.
  - **Test 4 (loopback trap is real):** pass. Bound to `127.0.0.1`, the host URL refuses.
    Confirmed from inside the container that `127.0.0.1:3000` returns 200 while the
    container's own IP (`10.88.0.24:3000`) refuses — podman forwards the published port
    to the container's network interface, not its loopback. The `config/CLAUDE.md`
    warning earns its place.
  - **Test 5a (registry inspection):** pass. All four projects `active`, slots distinct
    and sequential (0-3 → 20000/20010/20020/20030).
  - **Test 3:** not run. See START HERE.

- **Merged `feat/port-allocation` into `main`** (fast-forward `6b9377d..b507e3a`) and
  pushed. Branch left in place, not deleted.

- **Diagnosed why Fable showed a 200K context window** while Opus showed 1M, and
  verified a fix end to end. Findings, in the order they matter:

  - **The gateway is not the constraint.** Probed with deliberately oversized prompts —
    these fail validation before inference, so they cost nothing. Real backend ceilings:
    `claude-opus-5` 1M, `claude-fable-5-1` 1M, `claude-sonnet-5` 1M,
    `claude-haiku-4-5` **200K**. Fable's 1M applies with or without the
    `context-1m-2025-08-07` beta header.
  - **The 200K was Claude Code's own accounting.** It sizes the window from an internal
    model registry keyed on canonical names. A prefixed gateway ID (`itl-airms/…`) matches
    nothing, so it falls into a path it labels `source: "unknown-model"` and assumes a
    default window — then auto-compacts against that assumption.
  - **`[1m]` is an internal identifier, never a wire value.** Claude Code carries the
    model as `…claude-opus-5[1m]` for window accounting and display, and builds the HTTP
    request from a separate `canonicalModel` field. The gateway **403s** the suffixed
    string if sent literally, which is why the display name and the wire name differ.
  - **Why Opus worked and Fable didn't:** the registry marks Opus 5 `supports_1m_suffix`,
    so Claude Code appends `[1m]` itself **when resolving the startup default model only**
    (see the 2026-09-18 entry — this is narrower than it first appeared). Fable 5.1 and
    Sonnet 5 are marked `native_1m` *without* `supports_1m_suffix` — correct for a
    first-party ID, useless for a prefixed one that never matches the entry.
  - **Verified fix**, run end to end in this container:
    `ANTHROPIC_DEFAULT_FABLE_MODEL='itl-airms/claude-fable-5-1[1m]' claude -p … --model fable`
    returned `contextWindow: 1000000`, `canonicalModel: claude-fable-5-1`, HTTP 200.

### Current State
- Branch: `main`, clean, pushed. `feat/port-allocation` still exists at the same commit.
- Last checkpoint: this journal entry.
- Tests: no suite in this repo. Port feature verified manually — 4 of 5, see START HERE.
- Fable is working again (no longer 429s); the quota block from prior sessions is gone.

### Next Steps
1. **Apply the Fable/Sonnet context fix** in `~/.zshenv` — not yet done:
   ```bash
   export ANTHROPIC_DEFAULT_FABLE_MODEL='itl-airms/claude-fable-5-1[1m]'
   export ANTHROPIC_DEFAULT_SONNET_MODEL='itl-airms/claude-sonnet-5[1m]'
   export ANTHROPIC_DEFAULT_OPUS_MODEL='itl-airms/claude-opus-5[1m]'
   ```
   Leave Haiku bare — its real ceiling *is* 200K, so a suffix would make Claude Code
   believe 1M and skip compaction until the API hard-errors.
   **Opus DOES need the tag** — an earlier version of this entry said it did not, which
   was wrong and cost a session. Claude Code appends `[1m]` only when resolving the
   *startup default* model. An explicit `/model opus` resolves to the bare gateway ID and
   silently drops to 200K for the rest of the session; `/clear` does not restore it.
   Measured in-container:
   `/model opus[1m]` → 1,000,000 · `/model opus` → 200,000 ·
   `/model opus` with the tag in the env var → 1,000,000.
   Requires `mosh fresh` — the tier aliases enter via `--env-file` at `podman run`, and
   the resume path (`mosh:733-734`) re-passes only `MOSH_PORT*` and `MOSH_NEW_SESSION`.
   For the current session without a rebuild: `/model fable[1m]`.
2. Carry-forward: exercise `/model sonnet`, `/fast` and a `web-researcher` subagent call
   to prove those aliases resolve. Opus and Fable are now both confirmed working.
3. Carry-forward: `mosh fresh` remaining project containers for the gateway env, the
   API-key approval, Fable, and now ports.
4. Consider deleting `feat/port-allocation` now that it is merged.

### Open Questions / Blockers
- None. The Fable 429/quota blocker from prior sessions has cleared.

### Relevant Context — things worth not rediscovering

- **`mosh fresh` is safe for session continuity.** `cmd_fresh` is `podman rm -f` followed
  by `cmd_launch` (`mosh:954-980`) — it never touches the named volume, so `~/.claude`,
  the session history and `last-session-id` survive and the relaunch resumes the same
  conversation. Worth knowing before hesitating to run it.

- **Don't trust the gateway's `/v1/models` for context windows.** It reports
  `max_input_tokens: 200000` for *every* model, including Opus 5, which the oversized-prompt
  probe disproves. It is the first place anyone would look and it is wrong. The probe is
  the reliable method, and it is free: an over-limit prompt 400s at validation, unbilled,
  and the error names the real ceiling.

- **Output is capped at 64000 on the gateway** for Opus 5, Fable 5.1 and Sonnet 5 (Haiku
  8192). That happens to equal Claude Code's own default, so it only bites if
  `CLAUDE_CODE_MAX_OUTPUT_TOKENS` is raised above 64K expecting the models' 128K upper.

- **Compaction is client-side and driven by the assumed window.** Claude Code computes
  `effective_window` (clamped to the model window) and fires compaction at
  `effective_window` minus a summary buffer. So a wrong window assumption doesn't merely
  mislabel the UI — it discards context early. Relevant escape hatches:
  `CLAUDE_CODE_MAX_CONTEXT_TOKENS`, `CLAUDE_CODE_DISABLE_UNKNOWN_MODEL_WINDOW_ENFORCEMENT`,
  `CLAUDE_CODE_AUTO_COMPACT_WINDOW`. Prefer the per-model `[1m]` tag over
  `CLAUDE_CODE_MAX_CONTEXT_TOKENS`, which applies to whatever model is active and would
  wrongly claim 1M for Haiku.

- **A model switch re-resolves the window at runtime**, so `/model fable[1m]` widens the
  current session without a restart. `/autocompact` is clamped to the model window and can
  only lower it.

- **Fable 5.1 cache reads are $0.25/MTok against $10/MTok fresh input** — a 40× spread, and
  specific to 5.1 (plain Fable 5 has no such discount). Prompt-prefix stability is worth
  far more on Fable than on Opus. Its thinking is also always on, so `effort` is the
  spend lever, not context size.

- **`pkill -f "http.server"` kills the shell running it**, because the pattern matches that
  shell's own command line. Cost a test server and an exit-144 mystery this session. Use
  a bracketed pattern (`'[h]ttp\.server'`) or kill by PID.

## Session Handoff — 2026-09-18

### Completed This Session

- **Found the real scope of the `[1m]` behaviour, correcting the 2026-09-16 entry.**
  Claude Code appends `[1m]` only when resolving the **startup default** model. Any
  explicit `/model` switch resolves to the bare gateway ID and silently drops the session
  to a 200K window for good. Hit in a live container: Opus at 1M → `/model fable` → work →
  `/clear` → `/model opus` → stuck at 200K. `/clear` is unrelated and cannot restore it.

  Measured in-container with `claude -p --output-format json`:

  | Model argument | Resolves to | contextWindow |
  |---|---|---|
  | `opus[1m]` | `itl-airms/claude-opus-5[1m]` | 1,000,000 |
  | `opus` | `itl-airms/claude-opus-5` | 200,000 |
  | `itl-airms/claude-opus-5` | `itl-airms/claude-opus-5` | 200,000 |
  | `itl-airms/claude-opus-5[1m]` | `itl-airms/claude-opus-5[1m]` | 1,000,000 |
  | `opus`, with `[1m]` in `ANTHROPIC_DEFAULT_OPUS_MODEL` | `itl-airms/claude-opus-5[1m]` | 1,000,000 |

  That last row is why the env fix matters: with the tag in the variable, *every* path
  resolves to 1M, including a plain `/model opus`.

- **Corrected the 2026-09-16 handoff in place**, which advised that Opus needed no env
  change. It did. Left wrong, it would have reproduced this exact failure.

### Current State
- Branch: `main`, clean, pushed. Port feature merged; verification status unchanged from
  the 2026-09-16 entry (Test 3, Test 5b and the `(stale)` branch still open — see that
  entry's START HERE).
- No code changed this session; journal corrections only.

### Next Steps
1. Unchanged and still not done: apply the three `[1m]` exports in `~/.zshenv`, then
   `mosh fresh` each container. See the 2026-09-16 Next Steps for the exact block.
2. Everything else carries forward from the 2026-09-16 entry.

### Open Questions / Blockers
- None.

### Relevant Context — things worth not rediscovering

- **Recovering a session that has dropped to 200K:** `/model opus[1m]` (or the full
  `/model itl-airms/claude-opus-5[1m]`). A model switch re-resolves the window live, so
  no restart and no `mosh fresh` is needed. Both forms verified.

- **The failure is silent.** Nothing warns that the window shrank; it just starts
  auto-compacting four-fifths early. If a long session begins compacting sooner than
  expected, check the model string in `/status` before assuming anything else.

- **No model is persisted to disk in this setup** — `settings.json` has `"model": null`
  and `~/.claude.json` stores no model string anywhere. Model selection is pure session
  state, so a bad selection is never sticky across a restart and there is no file to
  hand-edit to fix one.
