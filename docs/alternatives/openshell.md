# NVIDIA OpenShell

> [!WARNING]
> **AI-generated, not reviewed.** This page was written by an AI coding assistant ([Claude Code](https://claude.com/claude-code)) from web research on 2026-10-09. It has not been reviewed or validated by a human: check the sources before relying on it.

> **Closeness to agent-sandbox: High.** Open-source, self-hosted sandbox runtime that runs opencode with deny-by-default egress on Docker, Podman, microVM or Kubernetes, with far finer policies, but much more complex to operate.

- **Project**: <https://github.com/NVIDIA/OpenShell> (Apache-2.0, NVIDIA)
- **Status**: very active. Created 2026-02-24, about 15.5k stars, 100+ contributors, last commit 2026-10-08. First stable line `v0.1.x` (`v0.1.2` on 2026-09-28) after the `v0.0.x` series (up to `v0.0.116`, 2026-08-28); weekly stable releases promised. Young project, APIs still changing (0.1.0 removed managed inference routes).
- **Category**: Local VM/container per agent

## Overview

OpenShell is a gateway (control plane) plus a per-sandbox supervisor that runs any OCI image as an agent sandbox. Inside the sandbox, Landlock and seccomp user notification confine files and system calls, and every TCP and DNS operation is handed to the supervisor, which checks it against a YAML policy, adds credentials and opens the real connection. Policies are per binary and can inspect HTTP, WebSocket, GraphQL, MCP and JSON-RPC requests. Its "Run Your First Agent" guide uses OpenCode with OpenRouter.

## How it works

| Aspect | OpenShell |
| --- | --- |
| Isolation boundary | Depends on the compute driver: container (Docker, Podman), Kubernetes pod (optionally Kata via runtime class), or microVM (libkrun, KVM on Linux). In all cases, plus Landlock (filesystem), seccomp, a single non-root identity with no capabilities. Requires Linux 6.2+ (Landlock ABI 3). |
| Network egress | Container networking disabled (Docker/Podman) or NetworkPolicy plus mTLS (Kubernetes) or no guest NIC (microVM). The only path out is an authenticated channel to the supervisor, which opens upstream connections. |
| Egress policy granularity | Per rule: list of binaries (real executable path, hash pinned) x list of `host:port` endpoints. Optional request inspection: HTTP method, path and query (`rest`), WebSocket messages, GraphQL operations, MCP tool names, JSON-RPC methods. `audit` or `enforce` mode. Deny rules win. Default policy: no network at all. |
| Proxy bypass resistance | Strong: TCP and DNS syscalls are intercepted (seccomp), no network device or route out, so `HTTP(S)_PROXY` is not needed. TLS is terminated with a per-sandbox CA injected into common trust store env vars (`SSL_CERT_FILE`, `NODE_EXTRA_CA_CERTS`...); `tls: skip` per endpoint. |
| Credentials | Providers stored by the gateway. The sandbox gets opaque placeholder tokens; the supervisor substitutes the real value only for destinations allowed by the provider profile. Profiles exist for Anthropic, OpenAI, OpenRouter, NVIDIA, GitHub, AWS, Google, Copilot, Claude Code, Codex, Cursor and others. |
| Code / filesystem | Code baked into the image or copied with `sandbox upload` / `--upload` and downloaded back. Landlock: working directory read-write, system paths read-only by default. Host mounts not covered in the docs read (not verified). |
| Persistence | Sandbox identity and config survive stop/start; filesystem persistence "follows the compute driver". `--no-keep` for ephemeral runs. |
| Interfaces (CLI, web UI) | `openshell` CLI, `openshell term` TUI (policy decisions, approvals), SSH config, `openshell forward` port forwarding, `openshell service expose` (gateway-managed HTTPS URL with gateway auth). SDKs in Python, TypeScript, Go, Rust. No built-in agent web UI; exposing `opencode serve` through a service URL is not verified. |
| Supported agents (opencode?) | Agent-agnostic: any agent installed in an OCI image. OpenCode is the quickstart example (`ghcr.io/anomalyco/opencode:latest`); provider profiles for Claude Code, Codex, Copilot, Cursor. Any OpenAI-compatible endpoint can be described with a custom profile (Albert not verified). |
| Platforms / deployment | Self-hosted. Linux (Debian/Ubuntu, amd64/arm64), macOS Apple Silicon (Docker Desktop), Windows WSL 2 (experimental). Docker 28+ or Podman 5 for single host, Helm chart for Kubernetes 1.29+ (CNI must enforce NetworkPolicy, OpenShift documented), microVM driver. No GPU required; `--gpu` optional (Docker CDI, `nvidia.com/gpu` on Kubernetes). OIDC, workspaces and RBAC for multi-user gateways. |
| Observability | Per-sandbox log of network, process, filesystem and config events in OCSF format (JSON export), `openshell logs`, gateway metrics. Policy advisor proposes narrow rules from denials; a formal "prover" flags risky policy changes. Anonymous telemetry on by default (`OPENSHELL_TELEMETRY_ENABLED=false`). |

## Compared with agent-sandbox

- **Better**:
  - Egress is enforced at syscall level for every process, not only proxy-aware tools ([../networking.md](../networking.md)).
  - Rules per binary and per HTTP method/path, instead of per domain for the whole sandbox.
  - Credentials never visible to the agent (agent-sandbox stores them on a readable volume, see [../github.md](../github.md)).
  - Kubernetes is implemented (Helm chart), not only documented ([../portability.md](../portability.md)); optional microVM isolation.
  - Structured audit logs, multi-user gateway with OIDC.
- **Worse or missing**:
  - Much larger system (gateway, supervisor, policies, provider profiles); steeper learning curve than one `compose.yaml`.
  - No equivalent of [../web-mode.md](../web-mode.md) out of the box; would need `service expose` and testing.
  - Requires Linux 6.2+ with Landlock and specific seccomp features; older hosts fail closed.
  - TLS interception by default (agent-sandbox does none); binary rules break when tools change interpreter paths.
  - Young 0.1 API with recent breaking changes; telemetry on by default.
- **Same idea**:
  - Deny-by-default egress with an allowlist, every connection logged.
  - Code lives inside the sandbox, not on a host mount.
  - Self-hosted, open license, model-agnostic, opencode supported.

## Adopting it

The strongest candidate to replace agent-sandbox on a server: open source, self-hosted, runs on a plain Linux Docker host or Kubernetes, and supports opencode. The owner would lose the simplicity of Docker Compose and the ready-made web mode. To match current features, the owner would need an opencode image, a provider profile for Albert, a policy translating [squid/allowed-domains.txt](../../squid/allowed-domains.txt) (with binary paths), and a tested way to expose `opencode serve`. These could be contributed upstream as an example or tutorial.

## Sources

Checked 2026-10-09:

- <https://docs.nvidia.com/openshell/latest/about/architecture>
- <https://docs.nvidia.com/openshell/latest/about/support-matrix>
- <https://docs.nvidia.com/openshell/latest/about/run-your-first-agent>
- <https://docs.nvidia.com/openshell/latest/how-it-works/policies/network-rules>
- <https://docs.nvidia.com/openshell/latest/how-it-works/policies/default-policy>
- <https://docs.nvidia.com/openshell/latest/how-it-works/inference>
- <https://docs.nvidia.com/openshell/latest/how-it-works/sandboxes/overview>
- <https://docs.nvidia.com/openshell/latest/how-it-works/sandboxes/runtimes>
- <https://docs.nvidia.com/openshell/latest/security/best-practices>
- <https://docs.nvidia.com/openshell/latest/observability/logging>
- <https://docs.nvidia.com/openshell/latest/upgrade/0-1-0>
- <https://github.com/NVIDIA/OpenShell> (README, LICENSE, releases, `docs/`, `providers/`)
