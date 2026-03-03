# Claude Code Development Container
# Compatible with both Podman and Docker.
# Build: podman build -t claude-dev -f Containerfile .

FROM node:20

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
    # Useful utilities
    git \
    curl \
    jq \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# Claude Code — installed globally via npm
# ---------------------------------------------------------------------------
RUN npm install -g @anthropic-ai/claude-code@latest

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

WORKDIR /workspace

# ---------------------------------------------------------------------------
# Entrypoint
# ---------------------------------------------------------------------------
ENTRYPOINT ["claude"]
CMD ["--dangerously-skip-permissions"]
