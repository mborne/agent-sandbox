# Images for the sandbox service, one target per tool, selected in compose.yaml
# with SANDBOX_IMAGE:
#   opencode  opencode CLI (https://opencode.ai), web UI with `opencode serve`
#   claude    Claude Code CLI (https://code.claude.com), web UI with ttyd
#
#   docker compose up -d --build                        # opencode (default)
#   SANDBOX_IMAGE=claude docker compose up -d --build
#   docker build --target claude sandbox

# Node.js major version (official node image tag) and uv version (official uv image tag)
ARG NODE_VERSION=24
ARG UV_VERSION=latest

# Binaries are copied from the official images: no extra apt repository or install script
FROM node:${NODE_VERSION}-bookworm-slim AS node
FROM ghcr.io/astral-sh/uv:${UV_VERSION} AS uv

# Common tools and scripts, shared by every target
FROM ubuntu:24.04 AS base

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl git jq python3 ripgrep unzip \
 && rm -rf /var/lib/apt/lists/*

# GitHub CLI from its official apt repository (Ubuntu's package lags behind)
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      -o /usr/share/keyrings/githubcli-archive-keyring.gpg \
 && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      > /etc/apt/sources.list.d/github-cli.list \
 && apt-get update \
 && apt-get install -y --no-install-recommends gh \
 && rm -rf /var/lib/apt/lists/*

# Node.js with npm and npx (for local MCP servers, `npx skills add`...)
COPY --from=node /usr/local/bin/node /usr/local/bin/node
COPY --from=node /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -s ../lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
 && ln -s ../lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx \
 && node --version && npm --version

# uv and uvx for Python tools; python3 above avoids downloading an interpreter at runtime
COPY --from=uv /uv /uvx /usr/local/bin/

# Setup helper, run with `docker compose exec sandbox setup-github`
COPY --chmod=755 scripts/setup-github.sh /usr/local/bin/setup-github
# Container main process: web mode (the target's sandbox-server) or idle
COPY --chmod=755 scripts/entrypoint.sh /usr/local/bin/sandbox-entrypoint
COPY --chmod=755 scripts/web-credentials.sh /usr/local/bin/web-credentials

# Run as the image's default unprivileged user (uid 1000)
USER ubuntu
WORKDIR /home/ubuntu

# Mount points for the named volumes (workspace, ~/.config, ~/.local).
# Created as ubuntu so that an empty named volume mounted here inherits uid
# 1000 ownership (WORKDIR or Docker alone would create them as root).
RUN mkdir -p /home/ubuntu/workspace /home/ubuntu/.config /home/ubuntu/.local
WORKDIR /home/ubuntu/workspace

ENTRYPOINT ["sandbox-entrypoint"]

FROM base AS opencode

# Empty = latest release, otherwise e.g. "1.0.0"
ARG OPENCODE_VERSION=""

ENV SANDBOX_IMAGE=opencode

# Official install script, installs the binary into ~/.opencode/bin
RUN curl -fsSL https://opencode.ai/install \
    | bash -s -- --no-modify-path ${OPENCODE_VERSION:+--version "$OPENCODE_VERSION"}

ENV PATH="/home/ubuntu/.opencode/bin:${PATH}"

# Setup helper, run with `docker compose exec sandbox setup-albert`
COPY --chmod=755 scripts/setup-albert.sh /usr/local/bin/setup-albert
COPY --chmod=755 scripts/server-opencode.sh /usr/local/bin/sandbox-server

FROM base AS claude

# Empty = latest release, otherwise e.g. "2.1.0"
ARG CLAUDE_CODE_VERSION=""

ENV SANDBOX_IMAGE=claude
# ~/.claude and ~/.claude.json would be lost on recreation: keep them on the config volume
ENV CLAUDE_CONFIG_DIR=/home/ubuntu/.config/claude
# The install is owned by root: update by rebuilding the image
ENV DISABLE_AUTOUPDATER=1

# npm rather than the native installer, which writes to ~/.local (hidden by the volume).
# ttyd serves the terminal UI in the browser (Claude Code has no web server of its own).
USER root
RUN npm install -g "@anthropic-ai/claude-code${CLAUDE_CODE_VERSION:+@$CLAUDE_CODE_VERSION}" \
 && npm cache clean --force \
 && apt-get update \
 && apt-get install -y --no-install-recommends ttyd \
 && rm -rf /var/lib/apt/lists/*
USER ubuntu

COPY --chmod=755 scripts/server-claude.sh /usr/local/bin/sandbox-server
