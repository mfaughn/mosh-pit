#!/usr/bin/env bash
#
# mosh container launch script.
#
# Runs inside the project container, mounted read-only at /mosh-config/launch.sh
# and executed by `mosh` via `podman exec ... bash /mosh-config/launch.sh`.
#
# Responsibilities, in order:
#   1. Sync config files from the read-only repo mount (/mosh-config) into the
#      writable ~/.claude named volume. Credentials are never overwritten.
#   2. Rebuild ~/.claude.json (Claude Code strips mcpServers on exit, so MCP
#      servers are re-injected on every launch). Secrets such as
#      OPENBRAIN_MCP_KEY come from the container environment via --env-file.
#   3. Conditionally inject the destructive_command_guard hook.
#   4. Seed / persist OAuth credentials via the shared volume.
#   5. Configure git credentials.
#   6. Launch Claude Code, resuming the last session unless MOSH_NEW_SESSION=1.
#
# NOTE: deliberately no `set -e`. Several steps are best-effort (missing config
# files are tolerated) and the Claude exit code is inspected after it runs, so
# aborting on the first non-zero status would break resume-failure reporting.

stty sane
export PATH="$HOME/.local/bin:$PATH"
mkdir -p ~/.claude

# Single files: copy straight across.
for f in settings.json CLAUDE.md mcp.json statusline.sh; do
  [ -f "/mosh-config/$f" ] && cp "/mosh-config/$f" "$HOME/.claude/$f" 2>/dev/null || true
done
[ -f "$HOME/.claude/statusline.sh" ] && chmod +x "$HOME/.claude/statusline.sh"

# Directories: copy contents into place (cp -rT merges into the target).
for d in agents templates uadf; do
  [ -d "/mosh-config/$d" ] && cp -rT "/mosh-config/$d" "$HOME/.claude/$d" 2>/dev/null || true
done

# Trust any extra CA certificates in /mosh-config/certs (e.g. the internal NIST
# CA needed to reach the LiteLLM gateway). Without this, Claude Code fails with
# "SSL certificate verification failed".
#
# Two variables are needed because they work differently:
#   NODE_EXTRA_CA_CERTS  Node ADDS these to its built-in bundle.
#   SSL_CERT_FILE etc.   These REPLACE the bundle, so they must point at a
#                        combined file — otherwise public sites stop verifying.
if compgen -G "/mosh-config/certs/*.pem" >/dev/null 2>&1; then
  EXTRA_CA_DIR="$HOME/.claude/certs"
  mkdir -p "$EXTRA_CA_DIR"
  cat /mosh-config/certs/*.pem > "$EXTRA_CA_DIR/extra-ca.pem"
  cat /etc/ssl/certs/ca-certificates.crt "$EXTRA_CA_DIR/extra-ca.pem" \
    > "$EXTRA_CA_DIR/combined-ca.pem"

  export NODE_EXTRA_CA_CERTS="$EXTRA_CA_DIR/extra-ca.pem"
  export SSL_CERT_FILE="$EXTRA_CA_DIR/combined-ca.pem"
  export REQUESTS_CA_BUNDLE="$EXTRA_CA_DIR/combined-ca.pem"
  export CURL_CA_BUNDLE="$EXTRA_CA_DIR/combined-ca.pem"
  export GIT_SSL_CAINFO="$EXTRA_CA_DIR/combined-ca.pem"

  echo -e "\033[0;32m[mosh]\033[0m Extra CA certificates trusted ($(grep -c 'BEGIN CERTIFICATE' "$EXTRA_CA_DIR/extra-ca.pem"))"
fi

# Sync ~/.claude.json from config/claude.json base + MCP credential injection.
# Start with config/claude.json (has theme, hasCompletedOnboarding, etc.),
# merge in any existing ~/.claude.json state, then re-inject MCP servers
# (Claude Code strips mcpServers on exit, so we re-add every launch).
python3 - <<'PYEOF'
import glob, json, os
base_path = "/mosh-config/claude.json"
mcp_path = "/mosh-config/mcp.json"
claude_path = os.path.expanduser("~/.claude.json")
# Start from base config (theme, onboarding, etc.)
try:
    with open(base_path) as f:
        base = json.load(f)
except Exception:
    base = {}
# Merge existing ~/.claude.json on top (preserves runtime state)
try:
    with open(claude_path) as f:
        existing = json.load(f)
except Exception:
    existing = {}
config = {**base, **existing}
# Re-apply base settings that should always win (Claude Code may overwrite these)
for key in ("theme", "hasCompletedOnboarding", "autoUpdates"):
    if key in base:
        config[key] = base[key]
# Load MCP servers from mcp.json and fill in credentials
try:
    with open(mcp_path) as f:
        mcp = json.load(f)
except Exception:
    mcp = {}
servers = mcp.get("mcpServers", {})
if "open-brain" in servers:
    key = os.environ.get("OPENBRAIN_MCP_KEY", "")
    if key:
        servers["open-brain"]["headers"]["x-brain-key"] = key
    else:
        del servers["open-brain"]
# Playwright MCP is opt-in per project — toggle with `mosh playwright on`.
# Spawning chromium for every project that does not need a browser is wasted
# overhead and another startup that can fail.
if "playwright" in servers:
    if not os.path.exists(os.path.expanduser("~/.claude/.playwright-enabled")):
        del servers["playwright"]
    else:
        # Resolve the chromium headless_shell binary dynamically. Playwright
        # revs the bundled Chromium version, so a hardcoded path goes stale
        # every few months and Playwright MCP fails to start.
        shells = sorted(glob.glob(
            "/ms-playwright/chromium_headless_shell-*/chrome-linux/headless_shell"
        ))
        if shells:
            args = servers["playwright"].setdefault("args", [])
            if "--executable-path" not in args:
                args.extend(["--executable-path", shells[-1]])
config["mcpServers"] = servers
with open(claude_path, "w") as f:
    json.dump(config, f, indent=2)
PYEOF

# Inject the destructive_command_guard PreToolUse hook into settings.json
# if the per-project sentinel ~/.claude/.dcg-enabled exists. Toggle with
# `mosh dcg on` / `mosh dcg off` from the host.
python3 - <<'PYEOF'
import json, os
sentinel = os.path.expanduser("~/.claude/.dcg-enabled")
if os.path.exists(sentinel):
    settings_path = os.path.expanduser("~/.claude/settings.json")
    try:
        with open(settings_path) as f:
            settings = json.load(f)
    except Exception:
        settings = {}
    pre = settings.setdefault("hooks", {}).setdefault("PreToolUse", [])
    has_dcg = any(
        h.get("matcher") == "Bash"
        and any(c.get("command") == "dcg" for c in h.get("hooks", []))
        for h in pre
    )
    if not has_dcg:
        pre.append({
            "matcher": "Bash",
            "hooks": [{"type": "command", "command": "dcg"}],
        })
        with open(settings_path, "w") as f:
            json.dump(settings, f, indent=2)
PYEOF

# Seed OAuth credentials from the shared volume if this project does not
# have its own yet. This lets you authenticate once and reuse across all
# mosh projects on this machine.
if [ -f /home/claude/.oauth-creds/.credentials.json ] && [ ! -f ~/.claude/.credentials.json ]; then
  cp /home/claude/.oauth-creds/.credentials.json ~/.claude/.credentials.json
  echo -e "\033[0;32m[mosh]\033[0m OAuth credentials loaded from shared store"
fi

# Global gitignore — prevents accidentally committing common artifacts.
if [ -f "/mosh-config/gitignore_global" ]; then
  cp "/mosh-config/gitignore_global" "$HOME/.gitignore_global"
  git config --global core.excludesfile "$HOME/.gitignore_global"
fi

# Configure git to authenticate with GitHub over HTTPS using a personal
# access token. Also rewrite SSH remote URLs to HTTPS so cloned repos
# that use git@github.com: work without SSH keys in the container.
# This only touches ~/.gitconfig (in the named volume) — host repos are
# never modified.
if [ -n "${GITHUB_PERSONAL_ACCESS_TOKEN:-}" ]; then
  git config --global credential.helper "$HOME/.git-credential-helper"
  git config --global url."https://github.com/".insteadOf "git@github.com:"
fi

# Resume last session if available (unless MOSH_NEW_SESSION is set).
RESUME_FILE="$HOME/.claude/last-session-id"
CLAUDE_ARGS=(--dangerously-skip-permissions)
RESUMING=0
if [ "${MOSH_NEW_SESSION:-0}" != "1" ] && [ -f "$RESUME_FILE" ]; then
  SESSION_ID=$(cat "$RESUME_FILE")
  if [ -n "$SESSION_ID" ]; then
    CLAUDE_ARGS+=(--resume "$SESSION_ID")
    RESUMING=1
    echo -e "\033[0;32m[mosh]\033[0m Resuming session: $SESSION_ID"
  fi
fi

claude "${CLAUDE_ARGS[@]}"
CLAUDE_EXIT=$?

# If resume failed, tell the user and clear the stale pointer.
if [ $CLAUDE_EXIT -ne 0 ] && [ $RESUMING -eq 1 ]; then
  echo ""
  echo -e "\033[0;31m[mosh] ERROR:\033[0m Session resume failed (exit code $CLAUDE_EXIT)."
  echo -e "\033[0;31m[mosh]\033[0m The saved session may be expired or corrupted."
  echo -e "\033[0;31m[mosh]\033[0m Run \033[1;33mmosh new\033[0m to start a fresh session."
  rm -f "$RESUME_FILE"
fi

# Persist OAuth credentials to shared volume so other projects can reuse them.
if [ -f ~/.claude/.credentials.json ]; then
  cp ~/.claude/.credentials.json /home/claude/.oauth-creds/.credentials.json
fi

# Save session ID for next resume.
NEWEST=$(ls -t "$HOME/.claude/projects/-workspace/"*.jsonl 2>/dev/null | head -1)
if [ -n "${NEWEST:-}" ]; then
  basename "$NEWEST" .jsonl > "$RESUME_FILE"
fi
