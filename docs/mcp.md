# MCP servers

MCP servers are declared in the global opencode configuration, on the `opencode-config` volume: they survive container recreation and apply to every repository in the sandbox.

## Recommended servers

| Name         | Data                                                                                                                                                                         | URL                                         |
| ------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------- |
| `datagouv`   | [data.gouv.fr](https://www.data.gouv.fr): catalog, datasets, tabular API ([datagouv/datagouv-mcp](https://github.com/datagouv/datagouv-mcp))                                 | `https://mcp.data.gouv.fr/mcp`              |
| `geocontext` | IGN Géoplateforme: geocoding, altitude, administrative units, cadastre, urban planning, WFS layers ([ignfab/geocontext](https://github.com/ignfab/geocontext), experimental) | `https://geollm.beta.ign.fr/geocontext/mcp` |
| `insee`      | INSEE: publications, MELODI datasets, RMES definitions ([InseeFrLab/McpDiffusion](https://github.com/InseeFrLab/McpDiffusion))                                               | `https://mcpdiffusion.lab.sspcloud.fr/mcp`  |

## Install

```bash
docker compose exec sandbox opencode mcp add datagouv --url https://mcp.data.gouv.fr/mcp
docker compose exec sandbox opencode mcp add geocontext --url https://geollm.beta.ign.fr/geocontext/mcp
docker compose exec sandbox opencode mcp add insee --url https://mcpdiffusion.lab.sspcloud.fr/mcp
```

`insee` also needs its domain in the proxy allowlist (`datagouv` and `geocontext` are covered by `.gouv.fr` and `.ign.fr`):

```bash
echo mcpdiffusion.lab.sspcloud.fr >> squid/allowed-domains.txt
docker compose restart proxy
```

Check the connection:

```bash
docker compose exec sandbox opencode mcp list
```

A server that fails to connect is usually blocked by the proxy: look for `TCP_DENIED` in `docker compose logs proxy`.
