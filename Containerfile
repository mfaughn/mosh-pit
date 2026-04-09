# Claude Code Development Container
# Compatible with both Podman and Docker.
# Build: podman build -t claude-dev -f Containerfile .

FROM node:22

# ---------------------------------------------------------------------------
# System dependencies
# ---------------------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Python
    python3 \
    python3-pip \
    python3-venv \
    # Playwright system dependencies (covers Chromium)
    libnss3 \
    libnspr4 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libcups2 \
    libdrm2 \
    libdbus-1-3 \
    libxkbcommon0 \
    libxcomposite1 \
    libxdamage1 \
    libxfixes3 \
    libxrandr2 \
    libgbm1 \
    libasound2 \
    libpango-1.0-0 \
    libpangocairo-1.0-0 \
    # Minimal init process — reaps zombie subprocesses (see tini-fix-brief.md)
    tini \
    # Useful utilities
    git \
    curl \
    jq \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# Python: Playwright browser automation library
# ---------------------------------------------------------------------------
RUN pip3 install --break-system-packages playwright

# ---------------------------------------------------------------------------
# Node: Playwright MCP server (official Microsoft package)
# Install MCP first, then use its bundled playwright to install Chromium
# so the browser version matches what the MCP server expects.
# ---------------------------------------------------------------------------
ENV PLAYWRIGHT_BROWSERS_PATH=/ms-playwright
ENV TERM=xterm-256color
RUN npm install -g @playwright/mcp@latest

# Install Chromium for both the MCP server and the Python playwright package.
# They may bundle different playwright-core versions expecting different builds.
RUN npx -y playwright@$(node -e "console.log(require('$(npm root -g)/@playwright/mcp/node_modules/playwright-core/package.json').version)") install chromium \
    && playwright install chromium

# Disable the crashpad handler — it cannot initialize in containers on ARM64
# and kills Chrome with SIGTRAP. Replace it with a no-op so Chrome starts cleanly.
RUN find /ms-playwright -name chrome_crashpad_handler -exec sh -c 'mv "$1" "$1.disabled" && echo "#!/bin/sh" > "$1" && chmod +x "$1"' _ {} \;

# ---------------------------------------------------------------------------
# Non-root user — Claude Code refuses --dangerously-skip-permissions as root
# ---------------------------------------------------------------------------
RUN useradd -m -s /bin/bash claude && \
    mkdir -p /home/claude/.claude /workspace && \
    chown -R claude:claude /home/claude /workspace /ms-playwright

USER claude

# ---------------------------------------------------------------------------
# Claude Code — native installer (npm method is deprecated)
# Must run as user claude so it installs to ~/.local/bin/claude.
# ---------------------------------------------------------------------------
ENV PATH="/home/claude/.local/bin:${PATH}"
RUN curl -fsSL https://claude.ai/install.sh | bash

# Git credential helper for GitHub token auth (used by mosh launcher).
# Reads the token from the environment at invocation time — nothing on disk.
COPY --chown=claude:claude config/git-credential-helper /home/claude/.git-credential-helper

WORKDIR /workspace

# ---------------------------------------------------------------------------
# Entrypoint — tini as PID 1 to reap zombie subprocesses
# ---------------------------------------------------------------------------
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["claude", "--dangerously-skip-permissions"]
