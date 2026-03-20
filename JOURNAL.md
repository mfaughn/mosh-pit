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
