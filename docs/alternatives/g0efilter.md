# g0efilter

> [!WARNING]
> **AI-generated, not reviewed.** This page was written by an AI coding assistant ([Claude Code](https://claude.com/claude-code)) from web research on 2026-10-09. It has not been reviewed or validated by a human: check the sources before relying on it.

> **Closeness to agent-sandbox: Low.** A container egress filter, not an agent sandbox; but it is the closest drop-in candidate to replace our Squid component, on Docker Compose and Kubernetes.

- **Project**: <https://github.com/g0lab/g0efilter> (MIT, `g0lab`, mostly a single maintainer)
- **Status**: active, pre-1.0. Latest release v0.10.0 on 2026-10-03, about 75 releases since 2025-09, last commit 2026-10-08, about 11 stars. README warns that the configuration is not stable yet (checked 2026-10-09).
- **Category**: Network egress filter

## Overview

g0efilter is a Go agent that runs next to a workload and filters its outbound traffic by IP, CIDR or domain without decrypting TLS. Workload containers share its network namespace (`network_mode: "service:g0efilter"` in Compose, or as a pod sidecar), where it programs nftables. Optional parts: a dashboard (live logs, remote unblock, alerts) and a Kubernetes controller with `EgressPolicy` CRDs and sidecar injection.

## How it works

| Aspect | g0efilter |
| --- | --- |
| Isolation boundary | None of its own: it filters the shared network namespace. Workloads need no extra capability; the filter needs only `NET_ADMIN` (image built `FROM scratch`, read-only). |
| Network egress | Transparent: nftables rules in the shared namespace. `https` mode redirects ports 80/443 to local proxies that read the `Host` header or TLS SNI and then connect to the original destination. Other ports are blocked unless the IP is allowed. |
| Egress policy granularity | IPs, CIDRs, exact domains, wildcards, regular expressions. Allowlist (default deny) or denylist. Three modes: `https` (SNI/Host at connection time), `dns` (at lookup time), `dns-strict` (lookup + only resolved IPs allowed, any port, IPv4/IPv6). Audit and learning modes. Live policy reload. |
| Proxy bypass resistance | No reliance on proxy variables. `https` mode blocks hardcoded IPs and SNI-less TLS under default deny. `dns-strict` also blocks DNS-over-HTTPS and alternate resolvers. In `https` mode DNS to the container resolver stays open (DNS tunnelling not addressed, not verified in detail). |
| Credentials | Not handled (no injection). |
| Code / filesystem | Not handled. |
| Persistence | Not handled (policy directory mounted from the host). |
| Interfaces (CLI, web UI) | No CLI for users. Optional web dashboard for traffic, fleet policy and unblock requests. |
| Supported agents (opencode?) | Any workload; nothing agent-specific. |
| Platforms / deployment | Docker Compose, Podman, Kubernetes (Kustomize component, Helm library chart, post-renderer, mutating webhook), GitHub Action. Images on Docker Hub, cosign-signed. |
| Observability | Decision log (JSON Lines: allowed, blocked, audit), netfilter logs, Prometheus metrics, Kubernetes events, dashboard, notifications (chat, email, webhooks). |

## Compared with agent-sandbox

- **Better**:
  - Transparent filtering: tools that ignore `HTTP(S)_PROXY` are filtered instead of failing; no proxy settings in the sandbox.
  - SNI checked per connection without interception, so domain fronting through an allowed CONNECT host does not apply.
  - Wildcards and regular expressions, learning and audit modes to build the allowlist, live reload (we restart Squid).
  - `dns-strict` mode allows non-HTTP protocols (for example SSH to `github.com`) to allowed domains.
  - Ready-made Kubernetes integration, where our Kubernetes path is only documented ([portability.md](../portability.md)).
- **Worse or missing**:
  - Covers only egress: no agent image, workspace, persistence, web mode or credential handling.
  - The sandbox shares the filter's network namespace instead of being on an `internal` network with no route at all; security relies on the nftables rules being correct.
  - Younger and less audited than Squid; configuration not stable yet; mostly one maintainer.
- **Same idea**:
  - Domain allowlist, deny by default, no TLS interception, every decision logged.

## Adopting it

Not a replacement for agent-sandbox, but a possible replacement for the `proxy` service: run `g0efilter` with the policy directory and set `network_mode: "service:g0efilter"` on `sandbox`. This would change the design described in [networking.md](../networking.md) (no `internal` network, no proxy variables) and the `web` relay would have to reach the sandbox through the filter's namespace (not verified). We would keep the agent image, volumes, web mode and model agnosticism. Worth a test branch once its configuration stabilises.

## Sources

Checked 2026-10-09:

- <https://github.com/g0lab/g0efilter> (README, `LICENSE`, releases, contributors)
- [docs/modes.md](https://github.com/g0lab/g0efilter/blob/main/docs/modes.md), [docs/policy.md](https://github.com/g0lab/g0efilter/blob/main/docs/policy.md), [docs/configuration.md](https://github.com/g0lab/g0efilter/blob/main/docs/configuration.md), [docs/kubernetes.md](https://github.com/g0lab/g0efilter/blob/main/docs/kubernetes.md)
- Source: `agent/nftables/nftables.go`, `agent/g0efilter/app.go`
