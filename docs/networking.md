# Networking: outbound traffic control

The `sandbox` container has no route to the Internet. Its only way out is the Squid `proxy` service, which only allows ports 80 and 443, logs every request and, in `strict` mode, only allows the domains listed in [squid/allowed-domains.txt](../squid/allowed-domains.txt) (see [Proxy modes](#proxy-modes)).

## Topology

```mermaid
flowchart LR
    subgraph agent["network: agent (internal: true)"]
        sandbox["sandbox<br/>agent, git, curl<br/>HTTP(S)_PROXY=http://proxy:3128"]
    end
    proxy["proxy<br/>Squid :3128<br/>ports 80, 443<br/>(attached to agent and egress)"]
    subgraph egress["network: egress (bridge)"]
        nat["Docker NAT"]
    end
    internet(("Internet"))

    sandbox -->|"HTTP / CONNECT host:443"| proxy
    proxy -->|"ports 80, 443<br/>allowed domains only (strict)"| nat
    nat --> internet
    sandbox -.->|"BLOCKED: no route,<br/>no external DNS"| internet
```

| Network  | Docker option     | Members            | Role |
|----------|-------------------|--------------------|------|
| `agent`  | [`internal: true`](https://docs.docker.com/reference/cli/docker/network/create/#options) | `sandbox`, `proxy`, `web` | Isolated network: no gateway to the outside, Docker DNS resolves service names only (`sandbox`, `proxy`, `web`). |
| `egress` | standard bridge   | `proxy`            | Gives the proxy its outbound route to the Internet. |
| `web`    | standard bridge   | `web`              | Only used to publish the relay port `127.0.0.1:4096` on the host (web mode). |

`proxy` is the only container that can carry traffic from the sandbox to the Internet. The `web` relay is also attached to `agent` and to a bridge network, but it only carries inbound traffic to the sandbox, see [Inbound traffic: the nginx relay](#inbound-traffic-the-nginx-relay).

## How a request goes out

Tools in the sandbox (opencode or Claude Code, `git`, `curl`, npm…) pick up the proxy from the environment set in [compose.yaml](../compose.yaml): `HTTP_PROXY`, `HTTPS_PROXY` (and their lowercase forms), `NO_PROXY=localhost,127.0.0.1,proxy`, and `NODE_USE_ENV_PROXY=1` for Node.js-based tools.

```mermaid
sequenceDiagram
    participant S as sandbox
    participant P as proxy (Squid)
    participant D as github.com

    S->>P: CONNECT github.com:443
    Note over P: port 443? (strict: domain in allowlist?)
    P->>D: TCP connection (DNS resolved by Squid)
    P-->>S: 200 Connection established
    S->>D: TLS end to end, through the tunnel

    S->>P: CONNECT example.com:443
    Note over P: strict mode: not in allowlist
    P-->>S: 403 Forbidden (TCP_DENIED)
```

- **HTTPS** goes through a `CONNECT` tunnel. Squid only sees the target host and port, then relays the encrypted stream: there is no TLS interception, so no certificate to install in the sandbox and no visibility on the content.
- **Plain HTTP** (port 80) is forwarded by Squid itself, with the same checks.
- **DNS** is resolved by Squid, not by the sandbox. The sandbox cannot resolve external names at all, which also rules out DNS-based exfiltration.
- A tool that ignores the proxy variables does not bypass the filter: it simply fails to connect.

## Proxy modes

`SANDBOX_PROXY_MODE` (in `.env` or the environment) selects the mode:

| Mode | Allowed | Use |
|------|---------|-----|
| `audit` (default) | Ports 80 and 443, any destination | Low friction: new providers, MCP servers, registries or Git hosts work without configuration. Requests are logged, not restricted. |
| `strict` | Ports 80 and 443, domains in [squid/allowed-domains.txt](../squid/allowed-domains.txt) only | Limits where the agent can send data. Each new domain must be added to the allowlist. |

Apply a change by recreating the proxy:

```bash
SANDBOX_PROXY_MODE=strict docker compose up -d proxy
```

The proxy logs its mode at startup (`proxy mode: strict`) and exits with an error on an unknown value.

## Filtering rules

Defined in [squid/squid.conf](../squid/squid.conf), evaluated in order, first match wins:

| Rule | Effect |
|------|--------|
| `deny !Safe_ports` | Only ports 80 and 443 (no SSH on 22, no arbitrary ports). |
| `deny CONNECT !SSL_ports` | Tunnels only to port 443. |
| `deny manager` | No access to Squid's management interface. |
| `audit`: `allow localnet` | Clients from private networks (the `agent` network) to any destination. |
| `strict`: `allow localnet allowed_domains` | Clients from private networks to an allowed domain. |
| `deny all` | Everything else. |

The mode-specific rule is generated at startup: [squid/entrypoint.sh](../squid/entrypoint.sh) writes `/etc/squid/sandbox-mode.conf`, included by `squid.conf`, then runs the stock `ubuntu/squid` entrypoint. The `squid/` directory is mounted read-only on `/etc/squid/sandbox`.

### Allowlist (strict mode)

[squid/allowed-domains.txt](../squid/allowed-domains.txt) is ignored in `audit` mode. It holds one domain per line; a leading dot also matches subdomains (`.github.com` matches `api.github.com`). It covers the model providers and services documented here: Anthropic and Claude Code login, Albert API (`.gouv.fr`), GitHub, PyPI, npm, Open VSX, Ubuntu and Debian archives, IGN and INSEE. Anything else (another Git host, model provider or MCP server) must be added. After editing it, reload the proxy:

```bash
docker compose restart proxy
```

To find the missing domains, look for `TCP_DENIED` in the proxy logs (see below), or run in `audit` mode first and collect the domains from the logs.

Other settings: no cache (filtering only), and the client IP is not forwarded (`forwarded_for delete`, `via off`).

## Observing traffic

Squid logs every request to the container's stdout:

```bash
docker compose logs -f proxy
```

```
... 172.24.0.2 TCP_TUNNEL/200 587709 CONNECT github.com:443 - HIER_DIRECT/140.82.121.3 -
... 172.24.0.2 TCP_DENIED/403 3358 CONNECT example.com:443 - HIER_NONE/- text/html
... 172.24.0.2 TCP_DENIED/403 3342 CONNECT github.com:22 - HIER_NONE/- text/html
```

`TCP_TUNNEL` / `TCP_MISS` means allowed, `TCP_DENIED` means blocked (port other than 80 and 443, or domain not in the allowlist in `strict` mode). A denied request shows up in the sandbox as `CONNECT tunnel failed, response 403` (HTTPS) or an HTTP 403 (plain HTTP).

The log shows the host and port of HTTPS requests, not the URL or the content (no TLS interception). Logs only go to the container output: centralize them with the Docker logging driver if they must be kept.

## Inbound traffic: the nginx relay

Web mode needs the host to reach the web UI in the sandbox (code-server by default, or the agent web UI: `opencode serve` or ttyd). Docker does not publish ports of a container that is only on an `internal` network, so the `web` service (official `nginx:alpine` image) sits in between:

```mermaid
flowchart LR
    browser["Browser on the host"] -->|"127.0.0.1:4096"| web
    subgraph webnet["network: web (bridge)"]
        web["web<br/>nginx :4096"]
    end
    subgraph agent["network: agent (internal: true)"]
        sandbox["sandbox<br/>opencode serve, ttyd or code-server :4096"]
        proxy["proxy<br/>Squid :3128"]
    end
    web -->|"proxy_pass http://sandbox:4096"| sandbox
    sandbox -->|"outbound: HTTP(S)_PROXY"| proxy
```

- **Published on the loopback only**: `127.0.0.1:4096:4096` in [compose.yaml](../compose.yaml). The UI is not reachable from other machines; for remote access, see [web-mode.md](web-mode.md#security).
- **Fixed upstream**: [web/nginx.conf](../web/nginx.conf) has a single `server` that forwards every request to `http://sandbox:4096`. It is a reverse proxy, not a forward proxy: the sandbox cannot use it to reach another host, so it is no way around the Squid proxy.
- **One direction**: the relay opens connections to the sandbox, never the reverse. The sandbox's outbound traffic still goes through `proxy:3128`.
- **Long-lived connections**: HTTP/1.1 with the `Upgrade` / `Connection` headers forwarded (WebSocket for the terminal and VS Code), the `Host` header with its port (code-server checks the WebSocket `Origin` against it), `proxy_buffering off` (server-sent events for session updates) and a one-hour `proxy_read_timeout`.
- **No TLS, no authentication in nginx**: traffic stays on the host loopback, and access control is the web UI password (see [web-mode.md](web-mode.md#password)). Add TLS and authentication in front before exposing it beyond the loopback.
- **Name resolution**: nginx resolves `sandbox` through Docker DNS when it starts (`depends_on: sandbox` in [compose.yaml](../compose.yaml)). It answers `502 Bad Gateway` when the web UI is not running, for example with `SANDBOX_SERVER_ENABLED=0`.

The relay itself has an outbound route through the `web` bridge network (required to publish a port), but it runs nothing besides nginx with this static configuration, and no domain needs to be added to [squid/allowed-domains.txt](../squid/allowed-domains.txt).

To check the relay:

```bash
docker compose logs -f web                       # access log, one line per request
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:4096/   # 502: web UI unreachable
```

## Limits

- **`audit` mode does not restrict destinations**: on ports 80 and 443, the agent can send data to any domain and reach the host (through the `egress` bridge gateway), the local network, internal services and cloud metadata endpoints (`169.254.169.254`). Requests are only logged. Use `strict` mode when this matters; it also blocks these destinations unless their name is in the allowlist.
- In `strict` mode, filtering is per domain, not per URL or content: everything reachable on an allowed domain is reachable by the agent, including uploads if it holds credentials for that service. Keep the allowlist short and do not give the sandbox credentials it does not need (it has no Git credentials by default; if you run `setup-github`, use a fine-grained token limited to the repositories you need).
- Secrets the agent uses (model provider API key, `opencode auth login` and Claude Code credentials, GitHub token from `setup-github`) live in the sandbox and can be read by the agent; only `strict` mode limits where they could be sent.
- The `localnet` ACL accepts any private source address. The proxy publishes no port on the host, so only containers attached to its networks (and the Docker host itself) can reach it.
