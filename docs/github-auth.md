# GitHub Authentication in MoshPit Containers

**Status:** Implemented (2026-03-20)

## How it works

MoshPit automatically configures git to authenticate with GitHub when `GITHUB_PERSONAL_ACCESS_TOKEN` is set in `.env`. On every container launch, the `mosh` startup script:

1. Points `credential.helper` at `~/.git-credential-helper` — a script that reads the token from the environment (never written to disk)
2. Adds `url."https://github.com/".insteadOf "git@github.com:"` so repos cloned with SSH remotes transparently use HTTPS

Both settings live in `~/.gitconfig` inside the container's named volume. Host-side repo remotes are never modified.

### Files involved

| File | Purpose |
|---|---|
| `config/git-credential-helper` | Script that returns the token from `$GITHUB_PERSONAL_ACCESS_TOKEN` |
| `Containerfile` | COPYs the script to `~/.git-credential-helper` at image build time |
| `mosh` (SYNC_AND_LAUNCH) | Configures `credential.helper` and `url.insteadOf` on each launch |
| `.env` | Where the user sets `GITHUB_PERSONAL_ACCESS_TOKEN` |

## Manual setup for existing containers

If the container was built before the credential helper was added to the image, the `~/.git-credential-helper` script won't exist. Run these commands inside the container to set it up without rebuilding:

```bash
# Create the credential helper script
cat > ~/.git-credential-helper << 'EOF'
#!/bin/sh
printf 'username=x-access-token\npassword=%s\n' "$GITHUB_PERSONAL_ACCESS_TOKEN"
EOF
chmod +x ~/.git-credential-helper

# Configure git to use it
git config --global credential.helper "$HOME/.git-credential-helper"
git config --global url."https://github.com/".insteadOf "git@github.com:"
```

This only needs to be done once per container — the settings persist in the named volume across restarts. After the next `mosh build` + `mosh fresh`, this happens automatically.

To add this to a project's `.claude-dev/provision.sh` so it survives `mosh fresh` even before an image rebuild:

```bash
# GitHub credential helper (temporary — remove after mosh image rebuild)
if [ -n "${GITHUB_PERSONAL_ACCESS_TOKEN:-}" ] && [ ! -f /home/claude/.git-credential-helper ]; then
  cat > /home/claude/.git-credential-helper << 'CREDEOF'
#!/bin/sh
printf 'username=x-access-token\npassword=%s\n' "$GITHUB_PERSONAL_ACCESS_TOKEN"
CREDEOF
  chmod +x /home/claude/.git-credential-helper
fi
```

The `mosh` launcher handles the `git config` commands automatically on each launch, so the provision script only needs to create the script file itself.
