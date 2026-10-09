#!/usr/bin/env bash
# Main process of the sandbox container (set in compose.yaml): web mode,
# `opencode serve` on port 4096, reached from the host through the "web"
# relay (see docs/web-mode.md). The terminal UI still works alongside.
#
#   docker compose up -d
#   docker compose exec sandbox web-credentials   # URL, user and password
#   OPENCODE_SERVER_ENABLED=0 docker compose up -d  # terminal UI only, stay idle
#
# Password: OPENCODE_SERVER_PASSWORD if set (e.g. in .env), otherwise generated
# on first start and kept on the opencode-config volume. It is never printed to
# the logs: `web-credentials` reads it back on demand.
set -euo pipefail

if [[ "${OPENCODE_SERVER_ENABLED:-1}" == "0" ]]; then
  echo "Web UI disabled (OPENCODE_SERVER_ENABLED=0): use 'docker compose exec sandbox opencode'"
  exec tail -f /dev/null
fi

PORT=${OPENCODE_SERVER_PORT:-4096}
PASSWORD_FILE=${XDG_CONFIG_HOME:-$HOME/.config}/opencode-sandbox/web-password

if [[ -z "${OPENCODE_SERVER_PASSWORD:-}" ]]; then
  if [[ ! -s "$PASSWORD_FILE" ]]; then
    mkdir -p "$(dirname "$PASSWORD_FILE")"
    (umask 077 && head -c 24 /dev/urandom | base64 | tr -d '/+=\n' > "$PASSWORD_FILE")
  fi
  OPENCODE_SERVER_PASSWORD=$(<"$PASSWORD_FILE")
  export OPENCODE_SERVER_PASSWORD
fi

echo "Web UI: http://127.0.0.1:${PORT} (credentials: docker compose exec sandbox web-credentials)"

exec opencode serve --hostname 0.0.0.0 --port "$PORT"
