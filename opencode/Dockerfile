# opencode CLI (https://opencode.ai) for the sandbox service

# Node.js major version (official node image tag) and uv version (official uv image tag)
ARG NODE_VERSION=24
ARG UV_VERSION=latest

# Binaries are copied from the official images: no extra apt repository or install script
FROM node:${NODE_VERSION}-bookworm-slim AS node
FROM ghcr.io/astral-sh/uv:${UV_VERSION} AS uv

FROM ubuntu:24.04

# Empty = latest release, otherwise e.g. "1.0.0"
ARG OPENCODE_VERSION=""

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

# Run as the image's default unprivileged user (uid 1000)
USER ubuntu
WORKDIR /home/ubuntu

# Official install script, installs the binary into ~/.opencode/bin
RUN curl -fsSL https://opencode.ai/install \
    | bash -s -- --no-modify-path ${OPENCODE_VERSION:+--version "$OPENCODE_VERSION"}

ENV PATH="/home/ubuntu/.opencode/bin:${PATH}"

# Setup helpers, run with `docker compose exec sandbox setup-albert` (or setup-github)
COPY --chmod=755 scripts/setup-albert.sh /usr/local/bin/setup-albert
COPY --chmod=755 scripts/setup-github.sh /usr/local/bin/setup-github

# Mount points for the named volumes (workspace, ~/.config, ~/.local).
# Created as ubuntu so that an empty named volume mounted here inherits uid
# 1000 ownership (WORKDIR or Docker alone would create them as root).
RUN mkdir -p /home/ubuntu/workspace /home/ubuntu/.config /home/ubuntu/.local
WORKDIR /home/ubuntu/workspace

ENTRYPOINT ["opencode"]
CMD ["--help"]
