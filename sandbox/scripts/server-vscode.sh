#!/usr/bin/env bash
# Web UI of the vscode image: VS Code in the browser (code-server). Started by
# sandbox-entrypoint, which sets SANDBOX_SERVER_PORT and SANDBOX_SERVER_PASSWORD
# (see docs/vscode.md). The agents run in the VS Code terminal or, for Claude
# Code, in its extension.
#
#   docker compose up -d   # SANDBOX_IMAGE=vscode (default)
#   http://127.0.0.1:4096/?folder=/home/ubuntu/workspace/<repo>
set -euo pipefail

# code-server reads the password from PASSWORD and has no user name. The empty
# --config keeps it from writing a config.yaml with a second, unused password.
export PASSWORD=$SANDBOX_SERVER_PASSWORD

exec code-server --bind-addr "0.0.0.0:$SANDBOX_SERVER_PORT" --auth password \
  --config /dev/null --disable-telemetry --disable-update-check \
  "$HOME/workspace"
