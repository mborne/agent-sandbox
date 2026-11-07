# VS Code in the browser

The `vscode` image (`SANDBOX_IMAGE=vscode`, the default in [compose.yaml](../compose.yaml), see [Choose the image](../README.md#choose-the-image)) serves [code-server](https://github.com/coder/code-server), VS Code in the browser, as its web UI, on the [web mode](web-mode.md) port, relay and password. It includes both agents:

- the opencode and Claude Code CLIs, run from the integrated terminal;
- the [Claude Code extension](https://open-vsx.org/extension/Anthropic/claude-code), pre-installed.

The `opencode` and `claude` images do not include code-server: they serve the agent's own web UI instead (see [web-mode.md](web-mode.md)).

## Usage

Start the stack:

```bash
docker compose up -d --build
docker compose exec sandbox web-credentials
# URL:      http://127.0.0.1:4096
# Password: ...
```

Open <http://127.0.0.1:4096> and log in with the password (code-server has no user name). The editor opens `/home/ubuntu/workspace`; to open a repository directly, use `http://127.0.0.1:4096/?folder=/home/ubuntu/workspace/<repo>`.

Use an agent:

- **Terminal** (`` Ctrl+` ``): `opencode` or `claude`. The terminal has the same environment as `docker compose exec` (proxy variables, `CLAUDE_CONFIG_DIR`…).
- **Claude Code extension**: the Claude icon in the activity bar or the editor title bar. It runs inside the container, like any code-server extension, so its traffic goes through the proxy. It ships its own Claude Code binary, next to the CLI, and shares its configuration and login (`CLAUDE_CONFIG_DIR=~/.config/claude`).

`setup-albert` and `setup-github` are available as in the other images.

## Configuration and extensions

- code-server keeps its settings, extensions and state in `~/.local/share/code-server` (`opencode-local` volume): they survive container recreation.
- It runs with `--config /dev/null`, so it does not write `~/.config/code-server/config.yaml` with a second password: the password is always the web mode one ([web-mode.md](web-mode.md#password)).
- Telemetry and the update check are disabled (`--disable-telemetry`, `--disable-update-check`). Update by rebuilding the image; pin a version with `--build-arg CODE_SERVER_VERSION=4.141.0`.
- The Claude Code extension is installed at build time as a built-in extension (`/usr/lib/code-server/lib/vscode/extensions`), since the user extensions directory is hidden by the volume. Rebuild to update it, or pin a version with `--build-arg CLAUDE_CODE_EXTENSION_VERSION=2.1.319`. A copy installed from the extensions view goes to the volume and takes precedence.
- **Extensions**: code-server installs them from [Open VSX](https://open-vsx.org), not the Microsoft marketplace (proprietary Microsoft extensions such as Pylance are not available). Its domains, `open-vsx.org` (API) and `openvsx.eclipsecontent.org` (downloads), are in [squid/allowed-domains.txt](../squid/allowed-domains.txt). Extensions are third-party code, published by anyone, that runs in the sandbox with the agent's rights (workspace, GitHub token, agent credentials); their network access is limited by the same allowlist, so those that download binaries from other domains fail. To block them, remove the two lines and run `docker compose restart proxy`: the extensions view then shows errors, and the pre-installed Claude Code extension keeps working.

  When they are blocked, install a `.vsix` file copied into the container (`docker compose cp`) with "Extensions: Install from VSIX…".

## Security

Same model as the agent web UI ([web-mode.md](web-mode.md#security)): loopback only, password always set, outbound traffic through the Squid proxy. VS Code gives a full shell in the sandbox, which the agent web UI already does.

- The relay forwards the `Host` header with its port (`$http_host` in [web/nginx.conf](../web/nginx.conf)): code-server rejects WebSocket connections whose `Origin` does not match it, which also blocks cross-site WebSocket connections.
- code-server's built-in port proxy (`/proxy/<port>/`, `/absproxy/<port>/`) is available behind the same password: it lets the browser reach a development server started in the sandbox (for example `http://127.0.0.1:4096/proxy/3000/`). It only carries inbound traffic, like the relay.
- Images without an IDE (`opencode`, `claude`) do not include code-server at all, for a smaller image and attack surface.
