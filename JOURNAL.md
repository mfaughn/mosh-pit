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
