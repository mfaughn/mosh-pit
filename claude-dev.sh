#!/usr/bin/env bash
# =============================================================================
# claude-dev.sh — Setup and launcher for the Claude Code dev container
# =============================================================================
#
# FIRST-TIME SETUP:
#   bash claude-dev.sh setup
#
# LAUNCH:
#   claude-dev                             # mount current directory
#   claude-dev ~/projects/my-app           # mount a specific project
#   claude-dev ~/projects/fe ~/projects/be # mount multiple projects
#
# REBUILD IMAGE (after Containerfile changes):
#   claude-dev build
#
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration — override by setting these env vars before running
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_NAME="${CLAUDE_DEV_IMAGE:-claude-dev:latest}"
CLAUDE_CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$SCRIPT_DIR/config}"
COMPOSE_FILE="$SCRIPT_DIR/compose.yaml"
ENV_FILE="$SCRIPT_DIR/.env"

# ---------------------------------------------------------------------------
# Color output helpers
# ---------------------------------------------------------------------------
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()    { echo -e "${GREEN}[claude-dev]${NC} $*"; }
warn()    { echo -e "${YELLOW}[claude-dev]${NC} $*"; }
error()   { echo -e "${RED}[claude-dev] ERROR:${NC} $*" >&2; }

# ---------------------------------------------------------------------------
# Detect container runtime (podman preferred, docker fallback)
# ---------------------------------------------------------------------------
detect_runtime() {
  if command -v podman &>/dev/null; then
    echo "podman"
  elif command -v docker &>/dev/null; then
    echo "docker"
  else
    error "Neither podman nor docker found. Please install one."
    exit 1
  fi
}

RUNTIME=$(detect_runtime)

# ---------------------------------------------------------------------------
# Common: verify prerequisites before launching
# ---------------------------------------------------------------------------
preflight_check() {
  if [[ ! -f "$ENV_FILE" ]]; then
    error ".env not found. Run: $(basename "$0") setup"
    exit 1
  fi

  if ! $RUNTIME image exists "$IMAGE_NAME" 2>/dev/null && \
     ! $RUNTIME inspect "$IMAGE_NAME" &>/dev/null 2>&1; then
    warn "Image $IMAGE_NAME not found. Building now..."
    cmd_build
  fi
}

# ---------------------------------------------------------------------------
# Common: build the env and volume args used by both launch modes.
# Sets the global COMMON_ARGS array.
# ---------------------------------------------------------------------------
build_common_args() {
  # Source .env to detect auth mode
  set -a; source "$ENV_FILE"; set +a

  COMMON_ARGS=(
    -it
    --shm-size=256m
    --env-file "$ENV_FILE"
    -e PLAYWRIGHT_BROWSERS_PATH=/ms-playwright
    -e NO_UPDATE_NOTIFIER=1
    -v "$CLAUDE_CONFIG_DIR:/home/claude/.claude:z"
    -v "$CLAUDE_CONFIG_DIR/claude.json:/home/claude/.claude.json:z"
  )

  if [[ -n "${ANTHROPIC_VERTEX_PROJECT_ID:-}" ]]; then
    # Vertex AI mode: pass project/region and mount gcloud credentials
    local gcloud_dir="${GCLOUD_CONFIG_DIR:-$HOME/.config/gcloud}"
    COMMON_ARGS+=(
      -e CLAUDE_CODE_USE_VERTEX=1
      -e "CLOUD_ML_REGION=${CLOUD_ML_REGION:-global}"
      -v "$gcloud_dir:/home/claude/.config/gcloud:ro,z"
    )
    info "Auth: Vertex AI (project: $ANTHROPIC_VERTEX_PROJECT_ID)"
  elif [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
    # Direct API key mode: key is passed via --env-file, nothing else needed
    info "Auth: Anthropic API key"
  else
    error "No auth configured in $ENV_FILE"
    error "Set either ANTHROPIC_API_KEY or ANTHROPIC_VERTEX_PROJECT_ID"
    exit 1
  fi
}

# ---------------------------------------------------------------------------
# setup: first-time initialization
# ---------------------------------------------------------------------------
cmd_setup() {
  info "Running first-time setup..."

  # 1. Check for .env
  if [[ ! -f "$ENV_FILE" ]]; then
    if [[ -f "$SCRIPT_DIR/.env.example" ]]; then
      cp "$SCRIPT_DIR/.env.example" "$ENV_FILE"
      warn ".env created from .env.example — please edit it now:"
      warn "  $ENV_FILE"
      warn "Set ANTHROPIC_API_KEY or ANTHROPIC_VERTEX_PROJECT_ID, then re-run setup."
      exit 0
    else
      error ".env.example not found alongside this script. Cannot continue."
      exit 1
    fi
  fi

  # 2. Source .env to check required vars
  set -a; source "$ENV_FILE"; set +a

  if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
    info "Auth mode: Anthropic API key"
  elif [[ -n "${ANTHROPIC_VERTEX_PROJECT_ID:-}" ]]; then
    info "Auth mode: Vertex AI (project: $ANTHROPIC_VERTEX_PROJECT_ID)"
  else
    error "No auth configured. Set ANTHROPIC_API_KEY or ANTHROPIC_VERTEX_PROJECT_ID in $ENV_FILE"
    exit 1
  fi

  # 3. Verify container config directory exists
  if [[ ! -d "$CLAUDE_CONFIG_DIR" ]]; then
    error "Config directory not found: $CLAUDE_CONFIG_DIR"
    error "Expected config/ directory in the project repo."
    exit 1
  fi

  if [[ ! -f "$CLAUDE_CONFIG_DIR/settings.json" ]]; then
    error "settings.json not found in $CLAUDE_CONFIG_DIR"
    exit 1
  fi

  # 4. Ensure claude.json exists for user-level config
  if [[ ! -f "$CLAUDE_CONFIG_DIR/claude.json" ]]; then
    echo '{"hasCompletedOnboarding": true, "autoUpdates": false}' \
      > "$CLAUDE_CONFIG_DIR/claude.json"
    info "Created claude.json in $CLAUDE_CONFIG_DIR"
  fi

  info "Container config directory: $CLAUDE_CONFIG_DIR"

  # 5. Check gcloud credentials (Vertex AI only)
  if [[ -n "${ANTHROPIC_VERTEX_PROJECT_ID:-}" ]]; then
    local gcloud_creds="${GCLOUD_CONFIG_DIR:-$HOME/.config/gcloud}"
    if [[ ! -d "$gcloud_creds" ]]; then
      warn "gcloud config directory not found: $gcloud_creds"
      warn "Run: gcloud auth application-default login"
      warn "Then re-run setup or just launch — the mount will work once credentials exist."
    else
      info "gcloud credentials directory found: $gcloud_creds"
    fi
  fi

  # 6. Build the image
  cmd_build

  info "Setup complete! Run '$(basename "$0")' from any project directory to start."
}

# ---------------------------------------------------------------------------
# build: build or rebuild the container image
# ---------------------------------------------------------------------------
cmd_build() {
  info "Building container image: $IMAGE_NAME"
  $RUNTIME build -t "$IMAGE_NAME" -f "$SCRIPT_DIR/Containerfile" "$SCRIPT_DIR"
  info "Build complete."
}

# ---------------------------------------------------------------------------
# launch: run Claude Code against one or more project directories
#
# Usage:
#   cmd_launch                        # mounts current directory
#   cmd_launch /path/to/project       # mounts that directory
#   cmd_launch /path/a /path/b        # mounts both under /workspace/
# ---------------------------------------------------------------------------
cmd_launch() {
  preflight_check

  local projects=("$@")

  # Default to current directory if no paths given
  if [[ ${#projects[@]} -eq 0 ]]; then
    projects=("$(pwd)")
  fi

  # Resolve all paths to absolute
  local resolved=()
  for p in "${projects[@]}"; do
    local abs
    abs="$(cd "$p" 2>/dev/null && pwd)" || {
      error "Directory not found: $p"
      exit 1
    }
    resolved+=("$abs")
  done

  # Container name derived from the current working directory.
  local container_name="cc-$(basename "$(pwd)" | tr -cs 'a-zA-Z0-9_-' '-' | sed 's/-$//')"

  # Inject MCP servers into claude.json before launch.
  # Claude Code overwrites this file on exit, stripping manually-added keys.
  # We re-inject from mcp.json every launch so servers are always registered.
  local mcp_config="$CLAUDE_CONFIG_DIR/mcp.json"
  local claude_json="$CLAUDE_CONFIG_DIR/claude.json"
  if [[ -f "$mcp_config" && -f "$claude_json" ]]; then
    python3 -c "
import json, sys
with open('$claude_json') as f: cj = json.load(f)
with open('$mcp_config') as f: mcp = json.load(f)
cj['mcpServers'] = mcp.get('mcpServers', {})
with open('$claude_json', 'w') as f: json.dump(cj, f, indent=2)
" && info "MCP servers injected into claude.json"
  fi

  # Check if a stopped container with this name already exists.
  if $RUNTIME container exists "$container_name" 2>/dev/null; then
    info "Restarting existing container: $container_name"
    info "Press Ctrl+C or type /exit to quit."
    echo ""
    $RUNTIME start -ai "$container_name"
    return
  fi

  # No existing container — create a new one.
  build_common_args
  COMMON_ARGS+=(--name "$container_name")
  info "Container: $container_name (new)"

  if [[ ${#resolved[@]} -eq 1 ]]; then
    # --- Single project: mount at /workspace root ---
    local project_dir="${resolved[0]}"
    COMMON_ARGS+=(-v "$project_dir:/workspace:z")
    COMMON_ARGS+=(-w /workspace)
    info "Project: $project_dir → /workspace"
  else
    # --- Multiple projects: each mounted as /workspace/<dirname> ---
    COMMON_ARGS+=(-w /workspace)
    for project_dir in "${resolved[@]}"; do
      local dirname
      dirname="$(basename "$project_dir")"
      COMMON_ARGS+=(-v "$project_dir:/workspace/$dirname:z")
      info "Project: $project_dir → /workspace/$dirname"
    done
  fi

  info "Press Ctrl+C or type /exit to quit."
  echo ""

  $RUNTIME run "${COMMON_ARGS[@]}" "$IMAGE_NAME" --dangerously-skip-permissions
}

# ---------------------------------------------------------------------------
# save: snapshot a project's container as an image for backup
#
# Usage:
#   claude-dev save              # saves cc-<cwd> as cc-<cwd>:backup
#   claude-dev save my-tag       # saves cc-<cwd> as cc-<cwd>:my-tag
# ---------------------------------------------------------------------------
cmd_save() {
  local container_name="cc-$(basename "$(pwd)" | tr -cs 'a-zA-Z0-9_-' '-' | sed 's/-$//')"
  local tag="${1:-backup}"
  local image_tag="$container_name:$tag"

  if ! $RUNTIME container exists "$container_name" 2>/dev/null; then
    error "No container found: $container_name"
    error "Start claude-dev from this project directory first."
    exit 1
  fi

  info "Saving container '$container_name' as image '$image_tag'..."
  $RUNTIME commit "$container_name" "$image_tag"
  info "Saved."
  info "List snapshots: claude-dev snapshots"
  info "Restore:        claude-dev restore $tag"
}

# ---------------------------------------------------------------------------
# snapshots: list saved snapshots for the current project
# ---------------------------------------------------------------------------
cmd_snapshots() {
  local container_name="cc-$(basename "$(pwd)" | tr -cs 'a-zA-Z0-9_-' '-' | sed 's/-$//')"
  info "Saved snapshots for $container_name:"
  $RUNTIME images --format "table {{.Repository}}:{{.Tag}}  {{.CreatedSince}}  {{.Size}}" \
    | grep "^$container_name:" || echo "  (none)"
}

# ---------------------------------------------------------------------------
# restore: replace the current container with a saved snapshot
#
# Usage:
#   claude-dev restore            # restore from cc-<cwd>:backup
#   claude-dev restore my-tag     # restore from cc-<cwd>:my-tag
# ---------------------------------------------------------------------------
cmd_restore() {
  local container_name="cc-$(basename "$(pwd)" | tr -cs 'a-zA-Z0-9_-' '-' | sed 's/-$//')"
  local tag="${1:-backup}"
  local image_tag="$container_name:$tag"

  if ! $RUNTIME image exists "$image_tag" 2>/dev/null; then
    error "No snapshot found: $image_tag"
    info "Available snapshots:"
    cmd_snapshots
    exit 1
  fi

  # Remove the current container if it exists
  if $RUNTIME container exists "$container_name" 2>/dev/null; then
    info "Removing current container: $container_name"
    $RUNTIME rm -f "$container_name"
  fi

  # Launch from the saved image instead of the base image
  info "Restoring from snapshot: $image_tag"
  IMAGE_NAME="$image_tag"
  cmd_launch
}

# ---------------------------------------------------------------------------
# fresh: remove existing container and start clean from base image
# ---------------------------------------------------------------------------
cmd_fresh() {
  local container_name="cc-$(basename "$(pwd)" | tr -cs 'a-zA-Z0-9_-' '-' | sed 's/-$//')"

  if $RUNTIME container exists "$container_name" 2>/dev/null; then
    info "Removing existing container: $container_name"
    $RUNTIME rm -f "$container_name"
  fi

  # Shift off the "fresh" argument, pass remaining args to launch
  cmd_launch "$@"
}

# ---------------------------------------------------------------------------
# help
# ---------------------------------------------------------------------------
cmd_help() {
  cat <<EOF
Usage: $(basename "$0") [command] [project-path ...]

Commands:
  (none)    Launch Claude Code (resumes existing container or creates new)
  setup     First-time setup: create .env, verify config, build image
  build     (Re)build the container image
  save      Snapshot the project's container as an image (backup)
  snapshots List saved snapshots for the current project
  restore   Replace current container with a saved snapshot
  fresh     Remove existing container and start clean from base image
  help      Show this help

Launch modes:
  $(basename "$0")                          Mount current directory as /workspace
  $(basename "$0") ~/projects/my-app        Mount specific project as /workspace
  $(basename "$0") ~/proj/fe ~/proj/be      Mount multiple as /workspace/fe, /workspace/be

Environment variables (set in .env):
  ANTHROPIC_API_KEY             Direct Anthropic API key (option A)
  ANTHROPIC_VERTEX_PROJECT_ID   GCP project with Vertex AI (option B)
  CLOUD_ML_REGION               Vertex AI region (default: global)
  CLAUDE_CONFIG_DIR             Container Claude config (default: ./config in repo)
  GCLOUD_CONFIG_DIR             gcloud config path (default: ~/.config/gcloud)
  CLAUDE_DEV_IMAGE              Container image name (default: claude-dev:latest)

Example workflow:
  # One-time setup
  bash claude-dev.sh setup

  # Add to PATH (put in ~/.zshrc or ~/.bashrc)
  export PATH="\$PATH:$SCRIPT_DIR"

  # Daily use
  cd ~/projects/my-app && claude-dev
  # or
  claude-dev ~/projects/my-app
  # or multiple projects
  claude-dev ~/projects/frontend ~/projects/backend
EOF
}

# ---------------------------------------------------------------------------
# Main dispatch
# ---------------------------------------------------------------------------
case "${1:-}" in
  setup)          cmd_setup ;;
  build)          cmd_build ;;
  save)           shift; cmd_save "$@" ;;
  snapshots)      cmd_snapshots ;;
  restore)        shift; cmd_restore "$@" ;;
  fresh)          shift; cmd_fresh "$@" ;;
  help|-h|--help) cmd_help ;;
  "")             cmd_launch ;;
  *)
    # If the first arg is a directory, treat everything as project paths.
    # Otherwise it's an unknown command.
    if [[ -d "$1" ]]; then
      cmd_launch "$@"
    else
      error "Unknown command: $1"
      cmd_help
      exit 1
    fi
    ;;
esac
