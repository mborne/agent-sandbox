#!/usr/bin/env bash
# Give the sandbox GitHub credentials: gh CLI login, git credential helper and
# commit identity. Runs inside the sandbox image and writes ~/.config/gh/hosts.yml
# and ~/.config/git/config (on the opencode-config volume):
#
#   docker compose exec sandbox setup-github
#   docker compose exec -e GH_TOKEN=... sandbox setup-github
#
# Optional: GIT_USER_NAME, GIT_USER_EMAIL (default: GitHub name and noreply
# address), GITHUB_ALLOW_BROAD_TOKEN=1 to accept a token that is not a
# fine-grained PAT without confirmation.
set -euo pipefail

API=https://api.github.com
GIT_CONFIG=${XDG_CONFIG_HOME:-$HOME/.config}/git/config

cat <<'EOF'
The token is stored in plain text in the container: the agent can read and
use it. Use a fine-grained PAT with limited rights:
  https://github.com/settings/personal-access-tokens/new
  - Repository access: Only select repositories (only those to modify)
  - Permissions: Contents read/write, Pull requests read/write if needed
  - Expiration: short (a few days)
EOF

# 1. Token
token=${GH_TOKEN:-${GITHUB_TOKEN:-}}
# gh refuses to store a token while these are set
unset GH_TOKEN GITHUB_TOKEN
if [ -z "$token" ]; then
  read -rsp "GitHub token: " token
  echo
fi
[ -n "$token" ] || { echo "Empty token" >&2; exit 1; }

# 2. Check the token (through the proxy)
echo "Checking the token against $API ..."
headers=$(mktemp)
trap 'rm -f "$headers"' EXIT
if ! user_json=$(curl -fsS -D "$headers" -H @- "$API/user" <<<"Authorization: Bearer $token"); then
  echo "Failed: token rejected, or domain missing from squid/allowed-domains.txt (proxy returns 403)." >&2
  exit 1
fi
header() { sed -n "s/^$1: *//Ip" "$headers" | tr -d '\r'; }
login=$(jq -r .login <<<"$user_json")
echo "Account: $login"

expiry=$(header github-authentication-token-expiration)
if [ -n "$expiry" ]; then
  echo "Expires: $expiry"
else
  echo "Warning: the token never expires." >&2
fi

# 3. Anything but a fine-grained PAT reaches every repository of the account
if [[ $token != github_pat_* ]]; then
  echo "Warning: not a fine-grained PAT (github_pat_ prefix)." >&2
  echo "It reaches every repository of the account. Scopes: $(header x-oauth-scopes)" >&2
  if [ "${GITHUB_ALLOW_BROAD_TOKEN:-}" != 1 ]; then
    [ -t 0 ] || { echo "Refused. Force with GITHUB_ALLOW_BROAD_TOKEN=1." >&2; exit 1; }
    read -rp "Continue anyway? Type 'yes': " answer
    [ "$answer" = yes ] || { echo "Aborted." >&2; exit 1; }
  fi
fi

# 4. Store the token for gh, use gh as git credential helper
umask 077
gh auth login --hostname github.com --git-protocol https --insecure-storage --with-token <<<"$token"
mkdir -p "$(dirname "$GIT_CONFIG")"
GIT_CONFIG_GLOBAL=$GIT_CONFIG gh auth setup-git --hostname github.com

# 5. Commit identity
name=${GIT_USER_NAME:-$(jq -r '.name // .login' <<<"$user_json")}
email=${GIT_USER_EMAIL:-$(jq -r '"\(.id)+\(.login)@users.noreply.github.com"' <<<"$user_json")}
git config --file "$GIT_CONFIG" user.name "$name"
git config --file "$GIT_CONFIG" user.email "$email"
echo "Git identity: $name <$email>"

gh auth status --hostname github.com
echo "OK. To remove access: docker compose exec sandbox gh auth logout, then revoke the token on GitHub."
