# Agentic Workflow Firewall (awf)

> [!WARNING]
> **AI-generated, not reviewed.** This page was written by an AI coding assistant ([Claude Code](https://claude.com/claude-code)) from web research on 2026-10-09. It has not been reviewed or validated by a human: check the sources before relying on it.

> **Closeness to opencode-sandbox: Medium.** Its default network design is almost the same as ours (internal Docker network, dual-homed Squid with a domain allowlist), but it is a one-shot command wrapper built for GitHub Actions, not a persistent sandbox.

- **Project**: <https://github.com/github/gh-aw-firewall> (MIT, GitHub; moved from `githubnext/gh-aw-firewall`, which now redirects)
- **Status**: very active. Latest release v0.28.49 on 2026-10-08, several releases per week, last commit 2026-10-08, about 150 stars (checked 2026-10-09). Part of GitHub's [Agentic Workflows](https://github.com/github/gh-aw) project.
- **Category**: Network egress filter

## Overview

`awf` is a TypeScript CLI that runs one command inside a generated Docker Compose stack: a Squid proxy, an agent container and an API proxy sidecar. Outbound HTTP/HTTPS is restricted to an allowlist of domains. It is mainly used by `gh-aw` to run Copilot CLI, Claude Code or Codex in GitHub Actions, but it also installs as a standalone CLI on a Linux host (`install.sh`, then `sudo awf --allow-domains github.com -- <command>`).

## How it works

| Aspect | awf |
| --- | --- |
| Isolation boundary | Docker containers on the host kernel. The command runs in `chroot /host` with host binaries mounted read-only ("chroot mode", always on). Optional backends: gVisor, Docker Sandboxes (`sbx`) microVM, Cloud Hypervisor and NVX (previews). |
| Network egress | Default "network-isolation" mode: agent on an `internal: true` network (`awf-net`), Squid dual-homed on `awf-net` and an external bridge, the only way out. Legacy mode (`--legacy-security`): host iptables chain hooked into `DOCKER-USER` plus DNAT of ports 80/443 to Squid inside the agent container, then `NET_ADMIN` is dropped. |
| Egress policy granularity | Domains (allow and deny, wildcard patterns), ports. URL path rules with `--allow-urls` only when SSL Bump (TLS interception) is enabled. Squid checks both the CONNECT target and the TLS SNI (peek and splice, no decryption by default). |
| Proxy bypass resistance | Agent gets `HTTP(S)_PROXY`, but the network topology (or iptables) also blocks direct routes. IPv6 disabled in the agent. DNS goes through Docker's embedded resolver to configured upstreams; optional DNS-over-HTTPS sidecar. Docs acknowledge DNS tunnelling as a residual risk. |
| Credentials | LLM API keys held by an always-on API proxy sidecar (OpenAI, Anthropic, Copilot, Gemini, Vertex AI) that injects auth headers; the agent never sees them. `gh` access through a separate CLI proxy. Sensitive host files hidden with `/dev/null` overlays. |
| Code / filesystem | Host workspace (current directory or `$GITHUB_WORKSPACE`) mounted; empty writable home with selected subdirectories (see `docs/selective-mounting.md`). |
| Persistence | None by design: containers and volumes removed after each run (`docker compose down -v`); logs copied to `/tmp`. |
| Interfaces (CLI, web UI) | CLI only: `awf [options] -- <command>`, `--tty` for interactive agents such as Claude Code. `awf logs` (raw, stats, summary, audit). No web UI. |
| Supported agents (opencode?) | Any command in principle. Documented: Copilot CLI, Claude Code, Codex. opencode is not documented; the config validator explicitly rejects `apiProxy.enableOpenCode` as unsupported (not tested with opencode). |
| Platforms / deployment | Linux only (Ubuntu 22.04+, x86_64/arm64), Docker 20.10+ with Compose v2. No macOS or Windows. GitHub Actions (hosted, self-hosted, ARC with DinD), or any Linux host. |
| Observability | Squid access logs, structured audit log (`audit.jsonl`), token usage log, `awf logs` subcommands, optional OpenTelemetry. |

## Compared with opencode-sandbox

- **Better**:
  - SNI is checked against the allowlist, so domain fronting through an allowed CONNECT host is blocked. Our Squid only checks the CONNECT host.
  - LLM API keys stay in a sidecar and never reach the agent. Ours are readable inside the sandbox.
  - Optional DLP scanning, DNS-over-HTTPS, SSL Bump with URL rules, deny lists, rate limits.
  - Signed images (cosign), large test suite, backed by GitHub, very active.
  - Optional stronger isolation (gVisor, microVMs).
- **Worse or missing**:
  - One-shot: no long-lived sandbox, no persistent volumes for workspace, config or sessions.
  - Runs host binaries through chroot: the agent (and its tools) must be installed on the host. The host workspace is mounted, not cloned inside.
  - No web UI; nothing like our `opencode serve` relay.
  - opencode is not a supported target of the API proxy; provider support is fixed to five vendors (an OpenAI-compatible endpoint such as Albert is not verified).
  - Large and fast-moving code base (hundreds of source files, frequent releases), tuned to `gh-aw` and GitHub Actions concerns (MCP gateway, DIFC proxy, ARC).
  - Linux only; quick start uses `sudo`.
- **Same idea**:
  - Squid with a domain allowlist on ports 80/443, every request logged.
  - `internal` Docker network with a dual-homed proxy as the only exit (our [networking.md](../networking.md)), plus `HTTP(S)_PROXY` in the agent.
  - No TLS interception by default.

## Adopting it

Switching would mean wrapping each opencode run in `awf --tty -- opencode` on a Linux host with opencode installed on the host. We would lose the persistent sandbox (volumes, cloned repositories), web mode, and the Kubernetes path of [portability.md](../portability.md). Model agnosticism would depend on the API proxy, which does not list opencode or OpenAI-compatible third parties. Contributing upstream (opencode support, a persistent mode) is possible but the project's priorities are GitHub Actions. More realistic: borrow ideas for our Squid config, mainly SNI validation (`ssl_bump peek` + splice with an SNI ACL) and a credential-holding API proxy sidecar.

## Sources

Checked 2026-10-09:

- <https://github.com/github/gh-aw-firewall> (README, `LICENSE`, releases)
- [docs/architecture.md](https://github.com/github/gh-aw-firewall/blob/main/docs/architecture.md), [docs/network-isolation-design.md](https://github.com/github/gh-aw-firewall/blob/main/docs/network-isolation-design.md), [docs/egress-filtering.md](https://github.com/github/gh-aw-firewall/blob/main/docs/egress-filtering.md)
- [docs/api-proxy-sidecar.md](https://github.com/github/gh-aw-firewall/blob/main/docs/api-proxy-sidecar.md), [docs/chroot-mode.md](https://github.com/github/gh-aw-firewall/blob/main/docs/chroot-mode.md), [docs/selective-mounting.md](https://github.com/github/gh-aw-firewall/blob/main/docs/selective-mounting.md), [docs/compatibility.md](https://github.com/github/gh-aw-firewall/blob/main/docs/compatibility.md)
- Source: `src/cli-options.ts`, `containers/agent/setup-iptables.sh`, `src/host-iptables-chain.ts`, `src/config-file-validation.test.ts`
