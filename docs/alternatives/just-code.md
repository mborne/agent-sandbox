# just-code

> [!WARNING]
> **AI-generated, not reviewed.** This page was written by an AI coding assistant ([Claude Code](https://claude.com/claude-code)) from web research on 2026-10-09. It has not been reviewed or validated by a human: check the sources before relying on it.

> **Closeness to agent-sandbox: High.** Same team as albert-code, opencode in a microVM with Albert API, proxy-side credential injection and a sealed workspace; but no domain allowlist and no server or web deployment.

- **Project**: [etalab-ia/just-code](https://github.com/etalab-ia/just-code) (MIT, DINUM / IA dans l'État)
- **Status**: experimental R&D, created 2026-09-08, very active (v0.8.1 on 2026-10-07, several releases a week), Go CLI with CI and release-please
- **Category**: Local VM/container per agent

## Overview

The successor track to [albert-code](albert-code.md): a Go CLI that runs opencode in a [Microsandbox](https://github.com/microsandbox/microsandbox) microVM by default, with [Tart](https://tart.run) (macOS guest, for Xcode) and agent-vm (Lima) as explicit alternatives. Its README states it is "not a product" but a playground to measure UX and compare isolation boundaries. It shipped a Docker runtime earlier and removed it (only a migration helper is left in `internal/justcode/legacy_docker.go`).

## How it works

| Aspect | just-code (Microsandbox runtime, default) |
| --- | --- |
| Isolation boundary | microVM (libkrun) with its own kernel; Tart and Lima VMs as alternatives |
| Network egress | Microsandbox profile `public` (`NetworkPolicy.FromProfiles(NetworkProfilePublic)`): the whole public Internet; private networks, loopback and cloud metadata endpoints are blocked |
| Egress policy granularity | just-code exposes no domain allowlist. Microsandbox itself supports deny-by-default policies with IP, CIDR, port and domain rules (domain rules on HTTPS fail closed unless TLS interception is on) |
| Proxy bypass resistance | Network handled by the microVM runtime, not by `HTTP(S)_PROXY` variables |
| Credentials | Albert key stays on the host (OS keychain / Secret Service); the guest gets a placeholder that the runtime proxy replaces only for `albert.api.etalab.gouv.fr`. GitHub and Context7 bindings opt-in per project. On Tart and agent-vm the key is in clear in the guest and requires `--acknowledge-guest-credentials` |
| Code / filesystem | Sealed workspace: the host checkout is not mounted, files are copied through a default-deny filter (`.env`, symlinks, gitleaks findings excluded), changes come back through a reviewed export. Tart and agent-vm mount the checkout |
| Persistence | One instance per project; `recreate` loses guest sessions and tools |
| Interfaces (CLI, web UI) | `full` mode: opencode TUI in the guest, host terminal only. `backend` mode: `opencode serve` on `127.0.0.1:4096` with the host TUI attached. Dev previews on ports 3000-3010 |
| Supported agents (opencode?) | opencode only |
| Platforms / deployment | macOS, Linux (KVM), Windows (Windows Hypervisor Platform); workstation tool, no server or Kubernetes mode |
| Observability | Not verified |

## Compared with agent-sandbox

- **Better**: microVM isolation (own kernel); the model API key never enters the guest; sealed workspace with a secret filter; per-project instances; Windows and macOS support; tests, releases and decision records.
- **Worse or missing**: no domain allowlist, so the agent can reach any public host (the key is protected, the code is not); Albert-centric; workstation only (no shared server, no web UI for remote users, no Kubernetes path); requires KVM, so it does not run inside most cloud VMs without nested virtualization.
- **Same idea**: opencode, Albert API, État skills and MCP, `opencode serve` on port 4096, opt-in GitHub token, code kept apart from the host.

## Adopting it

The most natural place to converge: same organisation, same stack, active maintainers. What this repository would bring as contributions: a domain allowlist with logging (Microsandbox policies support domain rules, so it is mostly a matter of exposing them), the "server + web UI" use case, and a Docker runtime for hosts without KVM (which just-code deliberately dropped, so it may not be welcome). What would be lost by switching: running on a shared Linux server without nested virtualization, the Kubernetes path, model-agnostic setup.

## Sources

- <https://github.com/etalab-ia/just-code> (README, `docs/credentials.md`, `docs/workspace-security.md`, `docs/usage.md`, `docs/design.md`, `internal/justcode/microsandbox_sdk.go`, `internal/justcode/legacy_docker.go`), checked 2026-10-09
- <https://github.com/microsandbox/microsandbox> (`docs/networking/overview.mdx`), checked 2026-10-09
