#!/usr/bin/env bash
# Configure opencode to use Albert API (OpenAI-compatible).
# Runs inside the sandbox image and writes ~/.config/opencode/opencode.json
# (on the opencode-config volume):
#
#   docker compose exec sandbox setup-albert
#   docker compose exec -e ALBERT_API_KEY=... sandbox setup-albert
#
# Optional: ALBERT_MODEL (default model id), ALBERT_BASE_URL.
set -euo pipefail

BASE_URL=${ALBERT_BASE_URL:-https://albert.api.etalab.gouv.fr/v1}
DEFAULT_MODEL=${ALBERT_MODEL:-Qwen/Qwen3-Coder-30B-A3B-Instruct}
CONFIG=${XDG_CONFIG_HOME:-$HOME/.config}/opencode/opencode.json

# 1. API key
if [ -z "${ALBERT_API_KEY:-}" ]; then
  read -rsp "Albert API key: " ALBERT_API_KEY
  echo
fi
[ -n "$ALBERT_API_KEY" ] || { echo "Empty key" >&2; exit 1; }

# 2. Check the key and fetch the model list (through the proxy)
echo "Checking the key against $BASE_URL ..."
if ! models_json=$(curl -fsS -H @- "$BASE_URL/models" <<<"Authorization: Bearer $ALBERT_API_KEY"); then
  echo "Failed: key rejected, or domain missing from squid/allowed-domains.txt (proxy returns 403)." >&2
  exit 1
fi

# Keep chat models only (no embeddings, OCR, transcription...) when the API gives a type
models=$(jq -c '
  [.data[] | select((.type // "text-generation") | test("text-generation|image-text-to-text"))]
  | map({key: .id, value: {name: .id}}) | from_entries' <<<"$models_json")
if [ "$models" = "{}" ]; then
  models=$(jq -c '[.data[] | {key: .id, value: {name: .id}}] | from_entries' <<<"$models_json")
fi
if ! jq -e --arg m "$DEFAULT_MODEL" 'has($m)' <<<"$models" >/dev/null; then
  first=$(jq -r 'keys[0]' <<<"$models")
  echo "Model $DEFAULT_MODEL not offered by the API, default model: $first" >&2
  DEFAULT_MODEL=$first
fi
echo "Declared models:"
jq -r 'keys[] | "  - " + .' <<<"$models"

# 3. Merge into the existing config (other providers and settings are kept)
mkdir -p "$(dirname "$CONFIG")"
existing=$(cat "$CONFIG" 2>/dev/null || true)
[ -n "$existing" ] || existing='{}'
umask 077
jq --arg url "$BASE_URL" --arg key "$ALBERT_API_KEY" \
   --arg model "albert/$DEFAULT_MODEL" --argjson models "$models" '
  ."$schema" = "https://opencode.ai/config.json"
  | .provider.albert = {
      npm: "@ai-sdk/openai-compatible",
      name: "Albert API",
      options: {baseURL: $url, apiKey: $key},
      models: $models
    }
  | .model = $model' <<<"$existing" > "$CONFIG.tmp"
mv "$CONFIG.tmp" "$CONFIG"
echo "Config written: $CONFIG"

opencode models albert >/dev/null
echo "OK. Run: docker compose exec sandbox opencode <repo>"
