# GitHub credentials

The sandbox has no Git credentials by default, so the agent cannot push. `setup-github` gives it a GitHub token so it can push and use the `gh` CLI. Source: [sandbox/scripts/setup-github.sh](../sandbox/scripts/setup-github.sh).

```bash
docker compose exec sandbox setup-github
# non-interactive
docker compose exec -e GH_TOKEN=... sandbox setup-github
```

## Choose a narrow token

The token is stored in plain text in the container, where the agent can read it and use it on any allowed domain. **Use a [fine-grained personal access token](https://github.com/settings/personal-access-tokens/new)** with:

- Repository access: *Only select repositories*, limited to the repositories the agent works on.
- Permissions: *Contents* read/write, plus *Pull requests* read/write if the agent opens pull requests.
- A short expiration.

Tip: the creation form can be prefilled from the URL. For a token on your personal repositories, open (replace `<login>`):

```text
https://github.com/settings/personal-access-tokens/new?name=agent-sandbox&description=agent+sandbox&target_name=<login>&expires_in=30&contents=write&pull_requests=write
```

`target_name` is the resource owner (your login, or an organization), `expires_in` a number of days, and each permission is set with `<permission>=read|write`. Repository selection cannot be prefilled: pick *Only select repositories* and choose them before generating the token.

The script checks the token through the proxy and shows its expiration date. Any other token type (classic PAT, OAuth token) reaches every repository of the account: the script asks for an explicit confirmation, and refuses it in non-interactive mode unless `GITHUB_ALLOW_BROAD_TOKEN=1` is set.

## What the script configures

- Logs `gh` in (`~/.config/gh/hosts.yml`).
- Sets `gh` as the Git credential helper for `github.com`.
- Sets the commit identity (`~/.config/git/config`). It defaults to the GitHub name and `noreply` address; override it with `GIT_USER_NAME` and `GIT_USER_EMAIL`.

Both files are on the `opencode-config` volume and survive container recreation.

## Remove access

```bash
docker compose exec sandbox gh auth logout
```

Then revoke the token on GitHub.

## Without credentials

Copy the repository to the host and push from there:

```bash
docker compose cp sandbox:/home/ubuntu/workspace/<repo> ./<repo>
```

Alternatively, export the commits as patches from the container (`git format-patch`) and apply them elsewhere.
