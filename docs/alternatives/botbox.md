# BotBox

> [!WARNING]
> **AI-generated, not reviewed.** This page was written by an AI coding assistant ([Claude Code](https://claude.com/claude-code)) from web research on 2026-10-09. It has not been reviewed or validated by a human: check the sources before relying on it.

> **Closeness to opencode-sandbox: Low.** A Kubernetes egress sidecar with credential injection, not a sandbox: it only covers the network part, only on Kubernetes, and needs TLS interception for HTTPS.

- **Project**: <https://github.com/reoring/botbox> (MIT, individual maintainer `reoring`)
- **Status**: early. 26 commits between 2026-02-10 and 2026-02-12, no release, no published image (build it yourself), about 13 stars. No activity since 2026-02-12 (checked 2026-10-09).
- **Category**: Network egress filter

## Overview

BotBox is a Rust proxy that runs as a sidecar in the agent's pod. An init container installs iptables rules that redirect outbound HTTP (and optionally HTTPS) to it and drop all other TCP/UDP. It enforces a deny-by-default host allowlist and injects API keys read from Kubernetes Secrets into request headers, so the agent never holds them.

## How it works

| Aspect | BotBox |
| --- | --- |
| Isolation boundary | None of its own: it only filters the pod's network. Process and filesystem isolation are whatever the pod provides. |
| Network egress | Transparent: iptables NAT in the pod redirects TCP 80 to the proxy (8080), and TCP 443 to a TLS-terminating listener (8443) when HTTPS interception is enabled. A filter chain drops other TCP and UDP. The proxy runs as UID 1337 and is exempted by owner match. |
| Egress policy granularity | Exact host names (no wildcard or subdomain matching found in `src/allowlist.rs`), per-rule allowed ports (443 by default). `CONNECT` rejected. No path rules. |
| Proxy bypass resistance | Good for TCP: no reliance on proxy variables. DNS (port 53) is allowed, so DNS tunnelling remains possible. IPv6 covered only with `BOTBOX_ENABLE_IPV6=1`. Without HTTPS interception, port 443 is simply dropped: the agent must call `http://` URLs, which BotBox upgrades to HTTPS. |
| Credentials | Strong point: secrets in Kubernetes Secrets, mounted only in the sidecar, injected as headers per host (`header_rewrites` with `secret_ref`), hot-reloaded with inotify. |
| Code / filesystem | Not handled. |
| Persistence | Not handled. |
| Interfaces (CLI, web UI) | None for users; YAML config, Prometheus metrics and health endpoint on loopback. |
| Supported agents (opencode?) | Agent-agnostic. With HTTPS interception the agent must trust BotBox's CA (`NODE_EXTRA_CA_CERTS` for Node.js, so opencode should work, not verified). |
| Platforms / deployment | Kubernetes only (init container with `NET_ADMIN`, native sidecar). Quick start on kind. Plain Docker use is not documented. |
| Observability | Structured logs per request (allowed or denied), Prometheus metrics. |

## Compared with opencode-sandbox

- **Better**:
  - Credential injection at the network boundary: API keys never enter the agent container.
  - Transparent redirect: tools that ignore `HTTP(S)_PROXY` still go through the filter instead of failing.
  - Per-request header inspection (with interception), Host/SNI consistency check.
- **Worse or missing**:
  - Covers only egress; no container image, workspace, persistence, web UI or agent setup.
  - Kubernetes only; nothing for a single Docker host.
  - HTTPS needs TLS interception with a local CA, which we deliberately avoid (see [networking.md](../networking.md)).
  - Exact host matching only: every subdomain must be listed.
  - DNS left open; IPv6 optional.
  - Small, inactive since February 2026, no release.
- **Same idea**:
  - Deny-by-default domain allowlist, every request logged.
  - Matches the NetworkPolicy-based Kubernetes path in [portability.md](../portability.md), but with a sidecar instead of a separate proxy pod.

## Adopting it

BotBox cannot replace opencode-sandbox: it would at most replace Squid in the Kubernetes design of [portability.md](../portability.md), and only if we accept TLS interception. We would keep everything else (image, volumes, web mode) and lose the Docker Compose path for that component. Given its inactivity, its credential-injection design is more useful as a reference than as a dependency.

## Sources

Checked 2026-10-09:

- <https://github.com/reoring/botbox> (README, `LICENSE`, commit history, pull requests)
- [docs/architecture.md](https://github.com/reoring/botbox/blob/main/docs/architecture.md), [docs/security.md](https://github.com/reoring/botbox/blob/main/docs/security.md)
- Source: `scripts/iptables-init.sh`, `src/allowlist.rs`, `config.yaml`
