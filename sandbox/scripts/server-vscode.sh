#!/usr/bin/env bash
# VS Code in the browser (code-server), common to every image. Started by
# sandbox-entrypoint instead of the agent web UI when SANDBOX_SERVER=vscode,
# with SANDBOX_SERVER_PORT and SANDBOX_SERVER_PASSWORD (see docs/vscode.md).
# The agent runs in the VS Code terminal.
#
#   SANDBOX_SERVER=vscode docker compose up -d
#   http://127.0.0.1:4096/?folder=/home/ubuntu/workspace/<repo>
set -euo pipefail

# code-server reads the password from PASSWORD and has no user name. The empty
# --config keeps it from writing a config.yaml with a second, unused password.
export PASSWORD=$SANDBOX_SERVER_PASSWORD

exec code-server --bind-addr "0.0.0.0:$SANDBOX_SERVER_PORT" --auth password \
  --config /dev/null --disable-telemetry --disable-update-check \
  "$HOME/workspace"
