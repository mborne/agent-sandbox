# Claude Code reference devcontainer

> [!WARNING]
> **AI-generated, not reviewed.** This page was written by an AI coding assistant ([Claude Code](https://claude.com/claude-code)) from web research on 2026-10-09. It has not been reviewed or validated by a human: check the sources before relying on it.

> **Closeness to agent-sandbox: Medium.** Same shape (agent in a Docker container, non-root user, default-deny egress with an allowlist), but egress is an IP-based iptables firewall inside the container, the code is bind-mounted from the host, and it is an example rather than a maintained product.

- **Project**: [anthropics/claude-code `.devcontainer/`](https://github.com/anthropics/claude-code/tree/main/.devcontainer) (Anthropic; repository `LICENSE.md`: "All rights reserved", use subject to Anthropic's Commercial Terms, so not an open-source license)
- **Status**: Documented as "a working example rather than a maintained base image". Last change to `.devcontainer/` on 2026-06-30 (removal of `statsig.anthropic.com`); previous changes August 2025. The repository itself is very active (release v2.1.295 on 2026-10-08).
- **Category**: Reference devcontainer

## Overview

Three files: `devcontainer.json`, `Dockerfile` (`node:20`, user `node`, Claude Code installed with npm) and `init-firewall.sh`. The container starts with `NET_ADMIN` and `NET_RAW`, and `postStartCommand` runs `sudo /usr/local/bin/init-firewall.sh`, the only command `node` may run with sudo. The script sets default-deny iptables policies and allows a fixed list of destinations. The docs say this makes `--dangerously-skip-permissions` acceptable for trusted repositories.

## How the firewall works

1. Saves Docker's embedded DNS NAT rules (`127.0.0.11`), flushes all iptables tables, restores those DNS rules.
2. Allows UDP 53 out (any destination), TCP 22 out (any destination), loopback.
3. Creates an `ipset` `allowed-domains`. Adds GitHub's `web`, `api` and `git` CIDRs from `https://api.github.com/meta`, aggregated.
4. Resolves each allowed name once with `dig +noall +answer A` and adds the IPv4 addresses: `registry.npmjs.org`, `api.anthropic.com`, `sentry.io`, `statsig.com`, `marketplace.visualstudio.com`, `vscode.blob.core.windows.net`, `update.code.visualstudio.com`.
5. Allows the whole host `/24` (derived from the default gateway), sets `INPUT`, `FORWARD`, `OUTPUT` to `DROP`, allows established traffic and the ipset, rejects the rest.
6. Self-test: `https://example.com` must fail, `https://api.github.com/zen` must succeed.

## How it works

| Aspect | Claude Code devcontainer |
| --- | --- |
| Isolation boundary | Docker container, shared host kernel, user `node` (non-root). Container has `NET_ADMIN` and `NET_RAW`; `node` has sudo for the firewall script only. |
| Network egress | iptables default deny inside the container's own network namespace; allowlisted IPs only. |
| Egress policy granularity | IPv4 addresses and CIDRs, resolved once at start. Any domain served from an allowed IP (shared CDN, GitHub ranges) is reachable. Addresses that change after start are blocked until the script runs again. Ports are not restricted for allowed IPs. |
| Proxy bypass resistance | No proxy: applies to every process and protocol. Gaps: UDP 53 to any host (DNS tunnelling, any UDP service on port 53), TCP 22 to any host, the whole host `/24`. No `ip6tables` rules (only matters if Docker IPv6 is enabled; not verified). |
| Credentials | `~/.claude` on a named volume (`claude-code-config-${devcontainerId}`), readable by the agent. The docs warn it can be exfiltrated in bypass mode. |
| Code / filesystem | Host project bind-mounted at `/workspace`; edits land directly on the host. |
| Persistence | Named volumes for `~/.claude` and shell history; rest is rebuilt. |
| Interfaces (CLI, web UI) | VS Code (or any Dev Containers client, `devcontainer` CLI), `claude` in the terminal, VS Code extension. No web UI. |
| Supported agents (opencode?) | Claude Code. The pattern is agent-agnostic, but opencode, its provider domains and `opencode.ai` are not in the list; they would have to be added. |
| Platforms / deployment | Any Docker host with a Dev Containers client, GitHub Codespaces. Kubernetes: not covered; `NET_ADMIN` in the pod would be needed. |
| Observability | None: rejected packets are not logged; only the script output at start. |

## Compared with agent-sandbox

- **Better**:
  - Applies to all traffic, not only tools that honour `HTTP(S)_PROXY`, and needs no proxy container.
  - Simple: one container, one script, familiar editor workflow.
- **Worse or missing**:
  - Agent container holds `NET_ADMIN`; a root escalation inside the container could flush the rules. Our sandbox has no capability on egress and the filter is in another container.
  - IP-based allowlist: shared IPs over-allow, DNS changes break allowed domains, no wildcard domains.
  - Open DNS (UDP 53) and SSH (TCP 22) to anywhere, host `/24` open. Our sandbox has no external DNS and no route except Squid on 80/443.
  - No request log (we have Squid `access.log`).
  - Host code bind-mounted; we clone inside a volume.
  - Not open source, not maintained as a product, no web mode.
- **Same idea**:
  - Non-root user in Docker, named volumes for agent config, default-deny egress with an explicit allowlist, no TLS interception.

## Adopting it

Not worth switching: it is weaker on the points this project cares about (DNS, logging, keeping capabilities out of the agent container) and does not support opencode or a web UI. It is a good reference for a "devcontainer" entry point: a `devcontainer.json` that starts this project's compose services (sandbox plus Squid) would give the VS Code workflow without the IP firewall. Its license does not allow reuse of the script as is; the idea is generic.

## Sources

Checked 2026-10-09.

- [`.devcontainer/devcontainer.json`](https://github.com/anthropics/claude-code/blob/main/.devcontainer/devcontainer.json), [`Dockerfile`](https://github.com/anthropics/claude-code/blob/main/.devcontainer/Dockerfile), [`init-firewall.sh`](https://github.com/anthropics/claude-code/blob/main/.devcontainer/init-firewall.sh) and their [commit history](https://github.com/anthropics/claude-code/commits/main/.devcontainer)
- [Claude Code: Development containers](https://code.claude.com/docs/en/devcontainer)
- [Claude Code: Choose a sandbox environment](https://code.claude.com/docs/en/sandbox-environments)
- [anthropics/claude-code LICENSE.md](https://github.com/anthropics/claude-code/blob/main/LICENSE.md)
