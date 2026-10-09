#!/usr/bin/env bash
# Web UI of the claude image: the Claude Code terminal UI served in the browser
# by ttyd. Started by sandbox-entrypoint, which sets SANDBOX_SERVER_PORT,
# SANDBOX_SERVER_USERNAME and SANDBOX_SERVER_PASSWORD (see docs/web-mode.md).
# Each browser tab starts its own `claude` process, in the repository given in
# the URL:
#
#   SANDBOX_IMAGE=claude docker compose up -d --build
#   http://127.0.0.1:4096/?arg=<repo>   # claude in ~/workspace/<repo>
#   http://127.0.0.1:4096/              # claude in ~/workspace
set -euo pipefail

WORKSPACE=$HOME/workspace

# Run by ttyd for each connection, with the `arg` URL parameter if any
if [[ "${1:-}" == "--session" ]]; then
  repo=${2:-}
  if [[ "$repo" == */* || "$repo" == .* || ( -n "$repo" && ! -d "$WORKSPACE/$repo" ) ]]; then
    echo "Unknown repository '$repo': use a directory name of $WORKSPACE (?arg=<repo>)" >&2
    sleep 10
    exit 1
  fi
  cd "$WORKSPACE/$repo"
  exec claude
fi

# --url-arg passes the `arg` URL parameters to the command. --credential is
# basic auth: the password is visible in the process list (the agent can already
# read it in the environment) and logged at the default level, hence --debug 3
# (errors and warnings only).
exec ttyd --port "$SANDBOX_SERVER_PORT" --writable --url-arg --debug 3 \
  --credential "$SANDBOX_SERVER_USERNAME:$SANDBOX_SERVER_PASSWORD" \
  --client-option titleFixed="Claude Code" \
  sandbox-server --session
