#!/usr/bin/env bash
# Web UI of the opencode image: `opencode serve`. Started by sandbox-entrypoint,
# which sets SANDBOX_SERVER_PORT, SANDBOX_SERVER_USERNAME and
# SANDBOX_SERVER_PASSWORD (see docs/web-mode.md).
#
#   docker compose up -d   # SANDBOX_IMAGE=opencode (default)
set -euo pipefail

# opencode reads the basic auth credentials from its own variables
export OPENCODE_SERVER_USERNAME=$SANDBOX_SERVER_USERNAME
export OPENCODE_SERVER_PASSWORD=$SANDBOX_SERVER_PASSWORD

exec opencode serve --hostname 0.0.0.0 --port "$SANDBOX_SERVER_PORT"
