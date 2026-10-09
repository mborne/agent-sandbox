# Model provider

opencode needs a model provider (Claude Code uses Anthropic, see [below](#claude-code)). Its domain must be in [squid/allowed-domains.txt](../squid/allowed-domains.txt) (`.anthropic.com` and `.gouv.fr` already are).

## Albert API: `setup-albert`

`setup-albert` declares the [Albert API](https://guides.ia.numerique.gouv.fr/albert-api) (OpenAI-compatible) in opencode without editing JSON by hand. Source: [opencode/scripts/setup-albert.sh](../sandbox/scripts/setup-albert.sh).

```bash
docker compose exec sandbox setup-albert
# non-interactive
docker compose exec -e ALBERT_API_KEY=... sandbox setup-albert
```

The script:

1. asks for the API key (hidden input) and checks it through the proxy;
2. lists the chat models available;
3. declares the `albert` provider and sets the default model.

It writes to `~/.config/opencode/opencode.json` on the `opencode-config` volume, so the configuration survives rebuilds. It merges into the existing file, which keeps other providers and settings.

| Variable          | Default                                  |
| ----------------- | ---------------------------------------- |
| `ALBERT_API_KEY`  | Asked interactively                      |
| `ALBERT_MODEL`    | `Qwen/Qwen3-Coder-30B-A3B-Instruct`      |
| `ALBERT_BASE_URL` | `https://albert.api.etalab.gouv.fr/v1`   |

If the default model is missing from the API, the script picks the first available one.

## Other providers: `opencode auth login`

Interactive login, done once. Credentials are kept in the `opencode-local` volume.

```bash
docker compose exec sandbox opencode auth login
```

## Claude Code

The `claude` image ([Choose the agent](../README.md#choose-the-agent)) uses the Anthropic API. Log in on first run, with a claude.ai account or an Anthropic Console account (API key):

```bash
docker compose exec -it sandbox claude
```

Credentials are kept in `~/.config/claude` (`CLAUDE_CONFIG_DIR`, `opencode-config` volume). The required domains are in [squid/allowed-domains.txt](../squid/allowed-domains.txt), see [portability.md](portability.md#claude-code). `setup-albert` only configures opencode: Albert exposes an OpenAI-compatible API, not the Anthropic one.
