# Alternatives

> [!WARNING]
> **AI-generated, not reviewed.** This page was written by an AI coding assistant ([Claude Code](https://claude.com/claude-code)) from web research on 2026-10-09. It has not been reviewed or validated by a human: check the sources before relying on it.

Existing tools that sandbox coding agents, compared with agent-sandbox to decide whether to adopt one of them, contribute to it, or borrow ideas. One sheet per tool, research done on 2026-10-09 ([issue #1](https://github.com/mborne/agent-sandbox/issues/1)). These projects move fast: check the "Status" line of a sheet before relying on it.

## What we compare against

agent-sandbox runs opencode in a Docker container on an `internal` network. Its only way out is a Squid proxy with a domain allowlist ([networking.md](../networking.md)). Code and configuration live on named volumes, a web UI is published on the host loopback ([web-mode.md](../web-mode.md)), and the design maps to Kubernetes ([portability.md](../portability.md)). Its known weak points:

- shared host kernel ([docker-hardening.md](../docker-hardening.md));
- API keys and tokens readable by the agent;
- filtering per domain only;
- relies on tools honouring `HTTP(S)_PROXY` (those that don't fail, they are not filtered transparently).

## Overview

| Tool | Category | Closeness | Isolation | Egress allowlist | Secrets kept out of the agent | opencode | Web UI | Server / Kubernetes | License | Activity |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| **agent-sandbox** | Container per agent | — | Container | Domains (Squid) | No | Yes | Yes | Compose, K8s documented | MIT | — |
| [just-code](just-code.md) | VM per agent | High | microVM (Microsandbox) | No (public Internet; the runtime supports domain rules) | Yes (proxy substitution) | Yes | No (`opencode serve` on 4096 in backend mode) | Workstation only | MIT | Very active |
| [albert-code](albert-code.md) | VM per agent | High | VM (Lima) | No | No | Yes | No | Workstation only | MIT | Superseded by just-code |
| [Docker Sandboxes](docker-sandboxes.md) | VM per agent | High | microVM | Domains, CIDR, method/path, transparent | Yes (proxy injection) | Yes (template) | No | Headless Linux, no K8s | Proprietary | Very active |
| [NVIDIA OpenShell](openshell.md) | Sandbox runtime | High | Container, pod or microVM + Landlock/seccomp | Per binary, host:port, L7 rules | Yes (placeholders) | Yes (quickstart) | No | Docker, Podman, Helm | Apache-2.0 | Very active |
| [gh-aw-firewall](gh-aw-firewall.md) | Egress filter | Medium | Container (chroot on host binaries) | Domains (Squid) + SNI check | Yes (API proxy sidecar) | No (rejected) | No | Linux, one-shot runs | MIT | Very active |
| [sandbox-runtime](sandbox-runtime.md) | OS-level sandbox | Medium | Process (bubblewrap, Seatbelt) | Domains (host proxy) | No | Possible, not documented | No | Workstation | Apache-2.0 | Very active |
| [Claude Code devcontainer](claude-code-devcontainer.md) | Reference devcontainer | Medium | Container | IPs resolved at start (iptables) | No | No | No | Workstation | Not open source | Example only |
| [opencode-cloud](opencode-cloud.md) | opencode wrapper | Medium | Container | No | No | Fork, stale | Yes (passkeys, 2FA) | Compose, cloud templates | MIT | Inactive since 2026-02 |
| [jail](jail.md) | opencode wrapper | Medium | Container | No (`--network host`) | No | Yes | Yes (no auth) | Workstation | Unclear | Inactive |
| [codex-sandbox](codex-sandbox.md) | OS-level sandbox | Low | Process (bubblewrap + seccomp) | Optional, domains + method | No | Not documented | No | Workstation | Apache-2.0 | Very active |
| [g0efilter](g0efilter.md) | Egress filter | Low | — (filter only) | Domains, IPs, SNI, DNS | No | — | — | Compose, K8s | MIT | Active, pre-1.0 |
| [BotBox](botbox.md) | Egress filter | Low | — (K8s sidecar) | Exact hosts, transparent | Yes (header injection) | — | — | K8s only | MIT | Inactive |
| [opencode-sandbox plugin](opencode-sandbox-plugin.md) | opencode wrapper | Low | Tools only, in a remote sandbox | No | Yes (stay on host) | Yes (plugin) | — | Depends on provider | Unclear | Prototype |
| [Cloud platforms](cloud-platforms.md) | Cloud sandbox | Low | microVM, gVisor | Varies (Vercel, Cloudflare, Deno) | Varies | Guides for E2B, Daytona, Vercel, Cloudflare | Varies | SaaS (E2B self-host for evaluation) | Mostly proprietary | Active |

"Closeness" rates how well the tool could replace this repository for the same use: opencode with a domain allowlist, self-hosted.

## Findings

- **No tool covers everything this repository does.** None combines opencode, a domain allowlist, a web UI and a self-hosted server/Kubernetes deployment out of the box.
- **The closest tools go further on two of our weak points.** Docker Sandboxes, OpenShell and just-code keep API keys out of the sandbox (the proxy adds them on the way out) and use a microVM or syscall-level enforcement instead of relying on `HTTP(S)_PROXY`.
- **Our network design is not unusual.** gh-aw-firewall uses the same pattern: an internal Docker network and a dual-homed Squid with a domain allowlist. It adds an SNI check, which we could borrow.
- **opencode wrappers are weaker.** jail, opencode-cloud and the opencode-sandbox plugin have no egress filtering.

## Where to go next

Depending on the target use:

1. **Shared server, web UI, Kubernetes: [NVIDIA OpenShell](openshell.md).** It is the strongest candidate. It is open source, self-hosted, runs opencode, and has a Helm chart. Its policies are finer than ours and the agent never sees the credentials. The cost: a bigger system to operate than one `compose.yaml`, a young 0.1 API, and no ready-made web mode. Next step: run its opencode quickstart and translate [squid/allowed-domains.txt](../../squid/allowed-domains.txt) into an OpenShell policy. Add an Albert provider profile and check that `opencode serve` can be exposed with `openshell service expose`.
2. **Same ecosystem (Albert API, État skills, DINUM): [just-code](just-code.md).** It is the natural place to converge and contribute. It is run by the team behind albert-code, very active, and already better than us on secrets and the workspace. Two things are missing for our use: a domain allowlist (Microsandbox supports domain rules, just-code does not expose them) and a server or web mode. It requires KVM, so it does not run in most cloud VMs. Next step: open an issue on just-code about egress filtering and the server use case.
3. **Single developer workstation: [Docker Sandboxes](docker-sandboxes.md).** It is the most polished tool. It has a microVM, transparent egress filtering, credential injection and an opencode template. It is closed source, needs a Docker sign-in, and only supports project-level opencode config. Not suited to a shared server.

Whichever route is taken, two parts of this repository are worth keeping or moving to the chosen tool:

- **Replacing only the proxy:** [g0efilter](g0efilter.md) could replace Squid on Compose and Kubernetes. It filters without decrypting TLS, checks the SNI and filters DNS.
- **Ideas to borrow if this repository is kept:**
  - credential injection by a sidecar or proxy (gh-aw-firewall, BotBox, Docker Sandboxes);
  - an SNI check in Squid (gh-aw-firewall);
  - transparent redirection instead of `HTTP(S)_PROXY` (BotBox, g0efilter);
  - interactive approval of new domains (Docker Sandboxes, sandbox-runtime);
  - a microVM runtime such as Kata or gVisor in place of runc.

## Sheet format

Each sheet gives a closeness rating, project facts (license, maintainer, status as checked), a "How it works" table (isolation, egress, credentials, code, persistence, interfaces, agents, platforms, observability), a comparison with agent-sandbox, what adopting the tool would mean, and its sources. Facts that could not be checked are marked "not verified".
