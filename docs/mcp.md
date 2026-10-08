# MCP servers

opencode reads MCP servers from the `mcp` key of `~/.config/opencode/opencode.json`, on the `opencode-config` volume. Declared servers survive container recreation and apply to every repository in the sandbox.

Like any other request, MCP traffic goes through the proxy: the server's domain must be in [squid/allowed-domains.txt](../squid/allowed-domains.txt) (see [networking.md](networking.md)).

## Recommended servers

| Name        | Data                                                                                                                | URL                                          | Allowed by default        |
| ----------- | ------------------------------------------------------------------------------------------------------------------- | -------------------------------------------- | ------------------------- |
| `datagouv`  | [data.gouv.fr](https://www.data.gouv.fr): catalog, datasets, tabular API ([datagouv/datagouv-mcp](https://github.com/datagouv/datagouv-mcp)) | `https://mcp.data.gouv.fr/mcp`               | Yes (`.gouv.fr`)          |
| `geocontext` | IGN Géoplateforme: geocoding, altitude, administrative units, cadastre, urban planning, WFS layers ([ignfab/geocontext](https://github.com/ignfab/geocontext), experimental) | `https://geollm.beta.ign.fr/geocontext/mcp`  | Yes (`.ign.fr`)           |
| `insee`     | INSEE: publications, MELODI datasets, RMES definitions ([InseeFrLab/McpDiffusion](https://github.com/InseeFrLab/McpDiffusion)) | `https://mcpdiffusion.lab.sspcloud.fr/mcp`   | No: add `mcpdiffusion.lab.sspcloud.fr` |

All three are remote servers that need no API key. The sandbox only talks to the MCP server; the server calls the underlying APIs itself, so their domains (`data.geopf.fr`, `api.insee.fr`…) do not need to be allowed.

## Add a server

Interactive:

```bash
docker compose exec sandbox opencode mcp add
```

Or merge the recommended servers into the existing configuration (created by `setup-albert` or `opencode auth login`):

```bash
docker compose exec sandbox sh -c '
  umask 077
  f=~/.config/opencode/opencode.json
  [ -s "$f" ] || echo "{}" > "$f"
  jq ".mcp += {
    datagouv:   {type: \"remote\", url: \"https://mcp.data.gouv.fr/mcp\"},
    geocontext: {type: \"remote\", url: \"https://geollm.beta.ign.fr/geocontext/mcp\"},
    insee:      {type: \"remote\", url: \"https://mcpdiffusion.lab.sspcloud.fr/mcp\"}
  }" "$f" > "$f.tmp" && mv "$f.tmp" "$f"'
```

Resulting entries in `opencode.json`:

```json
{
  "mcp": {
    "datagouv": { "type": "remote", "url": "https://mcp.data.gouv.fr/mcp" },
    "geocontext": { "type": "remote", "url": "https://geollm.beta.ign.fr/geocontext/mcp" },
    "insee": { "type": "remote", "url": "https://mcpdiffusion.lab.sspcloud.fr/mcp" }
  }
}
```

Other options for remote servers: `enabled` (`false` keeps the entry without loading it), `headers` (e.g. `"Authorization": "Bearer ..."`), `oauth`, `timeout`. See the [opencode MCP documentation](https://opencode.ai/docs/mcp-servers/).

**Local servers** (`"type": "local"`, `"command": [...]`) run inside the sandbox. The image includes Node.js (`npx`) and `uv` (`uvx`), so servers started with `npx -y <package>` or `uvx <package>` work: their packages come from `registry.npmjs.org` or `pypi.org` / `files.pythonhosted.org`, which are in [squid/allowed-domains.txt](../squid/allowed-domains.txt). The APIs such a server calls must be allowed too, so prefer the remote endpoint when one exists.

## Commands

| Action                                          | Command                                                     |
| ----------------------------------------------- | ----------------------------------------------------------- |
| List servers and their connection status        | `docker compose exec sandbox opencode mcp list`             |
| Authenticate with an OAuth server               | `docker compose exec sandbox opencode mcp auth <name>`      |
| Remove stored OAuth credentials                 | `docker compose exec sandbox opencode mcp logout <name>`    |
| Debug a connection or OAuth flow                | `docker compose exec sandbox opencode mcp debug <name>`     |
| Disable a server without removing it            | set `"enabled": false` on its entry                         |

OAuth credentials are stored in `~/.local/share/opencode/mcp-auth.json`, on the `opencode-local` volume.

## Troubleshooting

A server that fails to connect is usually blocked by the proxy. Check for `TCP_DENIED` in `docker compose logs proxy`, add the domain to [squid/allowed-domains.txt](../squid/allowed-domains.txt), then run `docker compose restart proxy`.
