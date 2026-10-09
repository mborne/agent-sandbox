# Docker Sandboxes

> [!WARNING]
> **AI-generated, not reviewed.** This page was written by an AI coding assistant ([Claude Code](https://claude.com/claude-code)) from web research on 2026-10-09. It has not been reviewed or validated by a human: check the sources before relying on it.

> **Closeness to opencode-sandbox: High.** Same goal (run opencode with deny-by-default egress), stronger isolation (microVM) and credential handling, but closed source, local-machine oriented and without a web UI.

- **Project**: <https://docs.docker.com/ai/sandboxes/>, binaries in [docker/sbx-releases](https://github.com/docker/sbx-releases) (proprietary, "Copyright Docker Inc. All rights reserved"; free to use including commercially; Docker Inc.)
- **Status**: active, fast-moving. Stable `v0.47.0` on 2026-10-05, `v0.48.0-rc4` on 2026-10-08. Still a 0.x CLI. Cloud sandboxes and upstream proxy support are marked experimental.
- **Category**: Local VM/container per agent

## Overview

`sbx` runs each coding agent in its own microVM with its own Linux kernel and a private Docker Engine. All outbound TCP goes through a proxy on the host that applies a deny-by-default policy and injects API keys into requests, so keys never enter the VM. It ships ready-made templates for about ten agents, including OpenCode (`docker/sandbox-templates:opencode`). The same CLI can also create cloud sandboxes on Docker-managed infrastructure (paid, experimental).

## How it works

| Aspect | Docker Sandboxes |
| --- | --- |
| Isolation boundary | microVM per sandbox (own kernel). Agent is a non-root user with `sudo` inside the VM; the hypervisor is the boundary. Hypervisor per OS not documented (KVM required on Linux, Windows Hypervisor Platform on Windows). |
| Network egress | Every outbound TCP connection goes through a host-side proxy: a forward proxy for HTTP(S), a transparent proxy for other TCP. UDP off by default (experimental opt-in), ICMP blocked, DNS through an internal resolver that enforces the policy. |
| Egress policy granularity | Hostnames, wildcards (`*.example.com`, `**.example.com`), `host:port`, CIDR ranges. Optional HTTP method and path rules (`sbx policy --method --path`). Presets: `allow-all`, `balanced` (AI APIs, package managers, code hosts, registries, cloud services), `deny-all`. Unmatched requests can trigger an interactive approval (`sbx policy approval`). Paid org governance adds central policies. |
| Proxy bypass resistance | Strong: the transparent proxy catches clients that ignore `HTTP(S)_PROXY`, DNS is policy-enforced, no direct route out. HTTP method/path rules only apply to traffic through the forward proxy; transparent connections to such hosts are blocked. |
| Credentials | Stored on the host (`sbx secret set`, OS keyring, or a `0700` file on headless Linux). The proxy overwrites the auth header; the agent only sees a sentinel value. Custom secrets map a host to an env var (`sbx secret set-custom --host ... --env ...`). Only the forward proxy injects credentials. |
| Code / filesystem | Three modes: direct read-write mount of a host directory (default of `sbx run`), clone mode (host repo read-only, private clone in the VM), or mountless (files live in the VM). No host Docker socket. |
| Persistence | Everything in the VM (packages, images, agent state, mountless files) persists across stop/start until `sbx rm`. |
| Interfaces (CLI, web UI) | `sbx` CLI, agent TUI in the terminal. No web UI documented. Ports can be published to the host (`sbx ports --publish`, `127.0.0.1` by default); exposing `opencode serve` this way is not verified. |
| Supported agents (opencode?) | Claude Code, Codex, Copilot, Cursor, Devin, Docker Agent, Droid, Gemini, Kiro, OpenCode, plain shell. OpenCode: `sbx run opencode`, built-in secrets for OpenAI, Anthropic, Google, xAI, Groq, AWS, OpenRouter, Copilot. Documented limit: OpenCode user-level config is not available, only project-level config. |
| Platforms / deployment | macOS 14+ (Apple silicon), Windows 11 (x86-64), Ubuntu 24.04+ (x86-64, Arm) with KVM. No Docker Desktop or Docker Engine needed. Headless Linux is supported (FAQ). Requires a Docker sign-in. No Kubernetes deployment documented. Cloud sandboxes: Docker SaaS, pay-as-you-go. |
| Observability | `sbx policy log` lists allowed and blocked hosts per sandbox, matching rule and proxy path (`--json`). Audit logs only with paid org governance. CLI telemetry on by default (`SBX_NO_TELEMETRY` to disable). |

## Compared with opencode-sandbox

- **Better**:
  - Kernel isolation (microVM) instead of a shared host kernel ([../docker-hardening.md](../docker-hardening.md)).
  - API keys never enter the sandbox; opencode-sandbox stores them on a volume readable by the agent ([../model-provider.md](../model-provider.md), [../github.md](../github.md)).
  - Egress covers all TCP, not only proxy-aware tools; DNS is filtered; rules can use ports, CIDR, HTTP method and path ([../networking.md](../networking.md) filters by domain only).
  - Interactive approval of new destinations; private Docker Engine for the agent.
  - Maintained by Docker, many agent templates.
- **Worse or missing**:
  - Closed source; cannot audit or fork it. Requires a Docker account sign-in.
  - No web UI equivalent to [../web-mode.md](../web-mode.md).
  - No Kubernetes path ([../portability.md](../portability.md)); Linux support limited to Ubuntu 24.04+ with KVM (a cloud VM needs nested virtualization, not verified per provider).
  - OpenCode user-level config not available, which affects a global `~/.config/opencode/opencode.json` setup such as `setup-albert`.
  - Albert API is not a built-in secret; a custom secret should work but is not verified.
  - Default `sbx run` mounts the host directory read-write (opencode-sandbox clones inside the container).
- **Same idea**:
  - One isolated environment per agent, deny-by-default egress through a host-side proxy with an allowlist.
  - Persistent state across restarts, logs of every destination.

## Adopting it

Viable for a developer workstation running opencode in a terminal: it replaces the Squid allowlist, the volumes and the hardening work with a single CLI. It does not fit the server use case: no web UI, no Kubernetes, proprietary, and tied to a Docker sign-in. Contributing is not possible beyond issues on `docker/sbx-releases`. To switch, the owner would need to rebuild model setup around project-level opencode config and `sbx secret set-custom`, and would lose web mode and self-hosting on arbitrary Linux servers.

## Sources

Checked 2026-10-09:

- <https://docs.docker.com/ai/sandboxes/>
- <https://docs.docker.com/ai/sandboxes/install/>
- <https://docs.docker.com/ai/sandboxes/architecture/>
- <https://docs.docker.com/ai/sandboxes/security/isolation/>
- <https://docs.docker.com/ai/sandboxes/security/defaults/>
- <https://docs.docker.com/ai/sandboxes/governance/access-controls/network/>
- <https://docs.docker.com/ai/sandboxes/governance/access-controls/local/>
- <https://docs.docker.com/ai/sandboxes/governance/monitor-and-enforce/monitoring/>
- <https://docs.docker.com/ai/sandboxes/configuration/credentials/>
- <https://docs.docker.com/ai/sandboxes/agents/opencode>
- <https://docs.docker.com/ai/sandboxes/workflows/development/>
- <https://docs.docker.com/ai/sandboxes/cloud/local-vs-cloud/>
- <https://docs.docker.com/ai/sandboxes/faq/>
- <https://github.com/docker/sbx-releases> (LICENSE, releases)
