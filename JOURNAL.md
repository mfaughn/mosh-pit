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

### Relevant Context
- **dcg rationale**: mosh-pit's container boundary does NOT protect `/workspace` (it's a bind mount), so `rm -rf /workspace`, `git reset --hard`, `git push --force`, etc. really can lose work. dcg is opt-in rather than default-on because false positives would add daily friction against `--dangerously-skip-permissions`, which is the whole point of mosh.
- **dcg state model**: The sentinel is per-project (lives in the project's named volume `${container_name}-claude-home`), so toggling it for one project does not affect others. The hook gets injected by the launcher's python sync, which means `mosh dcg on` followed by `/exit` + `mosh` is the canonical activation flow.
- **dcg install method**: Used the official `install.sh` with `--no-configure --system`. Auto-detects platform (linux-aarch64 here), downloads the prebuilt binary from GitHub releases with checksum verification, installs to `/usr/local/bin/`. `--no-configure` skips all the auto-hook wiring (Claude Code, Gemini CLI, Cursor, etc.) so we control hook state ourselves via the sentinel.
- **chromium path resolution**: The glob-based approach picks the lexically-newest version, which works for the foreseeable future since Playwright revisions monotonically increase from the current 4-digit values. The container at this point has both `1208` and `1217` installed because rebuilds at different times added each; a fresh build today would only have the newest.
- **Available tools in CLAUDE.md**: `config/CLAUDE.md` now documents `gh`, `rg`, `fd`, `ast-grep`, `shellcheck`, `jq` so Claude prefers them over slower defaults like `find`/`grep`. Claude figures out tools from PATH on its own, but explicit documentation makes it more likely to reach for the less-famous ones (especially `ast-grep`).
