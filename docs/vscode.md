# VS Code in the browser

Both images ([Choose the agent](../README.md#choose-the-agent)) include [code-server](https://github.com/coder/code-server), VS Code in the browser. With `SANDBOX_SERVER=vscode`, it is served **instead of** the agent web UI, on the same port, relay and password ([web mode](web-mode.md)): the container runs a single server. The agent is used from the VS Code terminal, and the CLI still works with `docker compose exec`.

## Usage

Set `SANDBOX_SERVER=vscode` (in `.env` or the environment), then start the stack:

```bash
SANDBOX_SERVER=vscode docker compose up -d --build
docker compose exec sandbox web-credentials
# URL:      http://127.0.0.1:4096
# Password: ...
```

Open <http://127.0.0.1:4096> and log in with the password (code-server has no user name). The editor opens `/home/ubuntu/workspace`; to open a repository directly, use `http://127.0.0.1:4096/?folder=/home/ubuntu/workspace/<repo>`.

Run the agent in the integrated terminal (`` Ctrl+` ``): `opencode` or `claude`, depending on the image. The terminal has the same environment as `docker compose exec` (proxy variables, `CLAUDE_CONFIG_DIR`…).

To go back to the agent web UI, remove the variable (or set it to the image name, `opencode` or `claude`) and run `docker compose up -d`.

| `SANDBOX_SERVER`              | Server on port 4096                    |
| ----------------------------- | -------------------------------------- |
| empty (default) or image name | Agent web UI: `opencode serve` or ttyd |
| `vscode`                      | code-server                            |

Any other value stops the container with an error. `SANDBOX_SERVER_ENABLED=0` still disables web mode altogether.

## Configuration and extensions

- code-server keeps its settings, extensions and state in `~/.local/share/code-server` (`opencode-local` volume): they survive container recreation.
- It runs with `--config /dev/null`, so it does not write `~/.config/code-server/config.yaml` with a second password: the password is always the web mode one ([web-mode.md](web-mode.md#password)).
- Telemetry and the update check are disabled (`--disable-telemetry`, `--disable-update-check`). Update by rebuilding the image; pin a version with `--build-arg CODE_SERVER_VERSION=4.141.0`.
- **Extensions**: code-server installs them from [Open VSX](https://open-vsx.org), not the Microsoft marketplace. Its domains are **not** in [squid/allowed-domains.txt](../squid/allowed-domains.txt), so the extensions view shows errors and nothing can be installed. Extensions are third-party code that runs in the sandbox with the agent's rights; to allow them, add these lines and run `docker compose restart proxy`:

  ```
  # code-server: Open VSX extension marketplace (API and downloads)
  open-vsx.org
  openvsx.eclipsecontent.org
  ```

  Alternatively, install a `.vsix` file copied into the container (`docker compose cp`) with "Extensions: Install from VSIX…".

## Security

Same model as the agent web UI ([web-mode.md](web-mode.md#security)): loopback only, password always set, outbound traffic through the Squid proxy. VS Code gives a full shell in the sandbox, which the agent web UI already does.

- The relay forwards the `Host` header with its port (`$http_host` in [web/nginx.conf](../web/nginx.conf)): code-server rejects WebSocket connections whose `Origin` does not match it, which also blocks cross-site WebSocket connections.
- code-server's built-in port proxy (`/proxy/<port>/`, `/absproxy/<port>/`) is available behind the same password: it lets the browser reach a development server started in the sandbox (for example `http://127.0.0.1:4096/proxy/3000/`). It only carries inbound traffic, like the relay.
