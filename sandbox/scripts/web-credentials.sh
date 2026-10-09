#!/usr/bin/env bash
# Print the web mode URL, user and password (see docs/web-mode.md). The
# password is never written to the container logs; this is the way to get it.
#
#   docker compose exec sandbox web-credentials
#   docker compose exec sandbox web-credentials --password   # password only
set -euo pipefail

PORT=${SANDBOX_SERVER_PORT:-4096}
USERNAME=${SANDBOX_SERVER_USERNAME:-$SANDBOX_IMAGE}
PASSWORD_FILE=${XDG_CONFIG_HOME:-$HOME/.config}/agent-sandbox/web-password

if [[ "${SANDBOX_SERVER_ENABLED:-1}" == "0" ]]; then
  echo "Web UI disabled (SANDBOX_SERVER_ENABLED=0)" >&2
  exit 1
fi

# Same precedence as the entrypoint: chosen password first, then generated one
if [[ -n "${SANDBOX_SERVER_PASSWORD:-}" ]]; then
  password=$SANDBOX_SERVER_PASSWORD
elif [[ -s "$PASSWORD_FILE" ]]; then
  password=$(<"$PASSWORD_FILE")
else
  echo "No password yet: $PASSWORD_FILE is created when the sandbox container starts" >&2
  exit 1
fi

if [[ "${1:-}" == "--password" ]]; then
  printf '%s\n' "$password"
else
  printf 'URL:      http://127.0.0.1:%s\nUser:     %s\nPassword: %s\n' "$PORT" "$USERNAME" "$password"
fi
