#!/usr/bin/env bash
# Main process of the sandbox container (ENTRYPOINT of every image): web mode,
# one server on port 4096, reached from the host through the "web" relay (see
# docs/web-mode.md): the image's `sandbox-server` (agent web UI) or, with
# SANDBOX_SERVER=vscode, `sandbox-server-vscode` (VS Code, see docs/vscode.md).
# The CLI still works alongside.
#
#   docker compose up -d
#   docker compose exec sandbox web-credentials     # URL, user and password
#   SANDBOX_SERVER=vscode docker compose up -d      # VS Code instead of the agent web UI
#   SANDBOX_SERVER_ENABLED=0 docker compose up -d   # CLI only, stay idle
#
# Password: SANDBOX_SERVER_PASSWORD if set (e.g. in .env), otherwise generated
# on first start and kept on the opencode-config volume. It is never printed to
# the logs: `web-credentials` reads it back on demand.
set -euo pipefail

if [[ "${SANDBOX_SERVER_ENABLED:-1}" == "0" ]]; then
  echo "Web UI disabled (SANDBOX_SERVER_ENABLED=0): use 'docker compose exec sandbox ${SANDBOX_IMAGE:-bash}'"
  exec tail -f /dev/null
fi

# Empty or the image name: the agent web UI
case "${SANDBOX_SERVER:-$SANDBOX_IMAGE}" in
  "$SANDBOX_IMAGE") SERVER=sandbox-server ;;
  vscode) SERVER=sandbox-server-vscode ;;
  *)
    echo "Unknown SANDBOX_SERVER '${SANDBOX_SERVER}': use ${SANDBOX_IMAGE} (default) or vscode" >&2
    exit 1
    ;;
esac

PORT=${SANDBOX_SERVER_PORT:-4096}
PASSWORD_FILE=${XDG_CONFIG_HOME:-$HOME/.config}/agent-sandbox/web-password

if [[ -z "${SANDBOX_SERVER_PASSWORD:-}" ]]; then
  if [[ ! -s "$PASSWORD_FILE" ]]; then
    mkdir -p "$(dirname "$PASSWORD_FILE")"
    (umask 077 && head -c 24 /dev/urandom | base64 | tr -d '/+=\n' > "$PASSWORD_FILE")
  fi
  SANDBOX_SERVER_PASSWORD=$(<"$PASSWORD_FILE")
fi

# Empty values from compose.yaml mean "default"
export SANDBOX_SERVER_PASSWORD SANDBOX_SERVER_PORT=$PORT
export SANDBOX_SERVER_USERNAME=${SANDBOX_SERVER_USERNAME:-$SANDBOX_IMAGE}

echo "Web UI (${SANDBOX_SERVER:-$SANDBOX_IMAGE}): http://127.0.0.1:${PORT} (credentials: docker compose exec sandbox web-credentials)"

exec "$SERVER"
