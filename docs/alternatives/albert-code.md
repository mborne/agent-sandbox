# albert-code

> [!WARNING]
> **AI-generated, not reviewed.** This page was written by an AI coding assistant ([Claude Code](https://claude.com/claude-code)) from web research on 2026-10-09. It has not been reviewed or validated by a human: check the sources before relying on it.

> **Closeness to opencode-sandbox: High.** Same stack (opencode, Albert API, État skills, MCP), stronger isolation (VM), but no outbound filtering. It is being superseded by [just-code](just-code.md).

- **Project**: [etalab-ia/albert-code](https://github.com/etalab-ia/albert-code) (MIT, DINUM / IA dans l'État)
- **Status**: experimental "v1", no tagged release; last commit 2026-09-24 prepares the uninstall "before the switch to just-code"
- **Category**: Local VM/container per agent

## Overview

A one-command bundle for public servants: opencode running in a disposable [Lima](https://lima-vm.io) VM ([agent-vm](https://github.com/sylvinus/agent-vm), vendored), wired to the Albert API, with the État skills and MCP servers chosen per project. It is thin orchestration (shell scripts and config) on top of opencode. This sandbox started as a variant of it.

## How it works

| Aspect | albert-code |
| --- | --- |
| Isolation boundary | Lima VM (QEMU/KVM on Linux, Virtualization.framework on macOS): own kernel |
| Network egress | Full Internet access from the VM ("the agent is root in its VM and has the network") |
| Egress policy granularity | None |
| Proxy bypass resistance | Not applicable (no filtering) |
| Credentials | Albert key and optional `GH_TOKEN` in the VM `~/.zshenv`, from `~/.agent-vm/runtime.sh` on the host (`chmod 600`); readable by the agent |
| Code / filesystem | Host project directory mounted in the VM |
| Persistence | VM per project, host directory holds the code |
| Interfaces (CLI, web UI) | CLI only: `albert-code install / setup / run / update`, opencode TUI in the VM |
| Supported agents (opencode?) | opencode only, run with `--dangerously-skip-permissions` |
| Platforms / deployment | macOS and Linux workstations (KVM required on Linux), no Windows, no server or Kubernetes mode |
| Observability | None for network traffic |

## Compared with opencode-sandbox

- **Better**: kernel isolation from the host (VM); per-project setup (`AGENTS.md`, `opencode.json`, skills and MCP chosen at `setup`); guided install.
- **Worse or missing**: no outbound filtering, so a prompt injection can send the key or the code anywhere; built around the Albert API; host directory mounted (secrets in the checkout are visible); workstation only, no web UI.
- **Same idea**: opencode, Albert API, État skills, opt-in fine-grained GitHub PAT, agent runs unattended inside the boundary.

## Detailed differences

|                       | albert-code                                                                                                | This sandbox                                                                                                                                                                                          |
| --------------------- | ---------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Isolation             | Disposable Lima VM (kernel isolation from the host)                                                        | Docker containers (shared host kernel): host security relies on Docker hardening ([docker-hardening.md](../docker-hardening.md))                                                                      |
| Network               | No outbound filtering                                                                                      | `internal` network, Squid proxy with a domain allowlist, ports 80/443 only ([networking.md](../networking.md))                                                                                        |
| Model provider        | Built around the Albert API                                                                                | Model agnostic: any provider supported by opencode (`setup-albert` is a convenience, `opencode auth login` for the others), as long as its domain is allowed ([model-provider.md](../model-provider.md)) |
| Configuration scripts | Run when the VM starts (`~/.agent-vm/runtime.sh`, skill sync on each launch)                               | Run on demand (`docker compose exec sandbox setup-albert`), nothing runs at container start                                                                                                           |
| Configuration scope   | Per project: `albert-code setup` generates `opencode.json`, `AGENTS.md`, `.albert-code/` in the repository | Global to the sandbox: `~/.config/opencode/opencode.json` on the `opencode-config` volume, the repository is untouched                                                                                |
| Code                  | Host project directory mounted in the VM                                                                   | Repository cloned inside the container (`opencode-data` volume), copied back to the host afterwards                                                                                                   |
| Git credentials       | `GH_TOKEN` and Git identity provided through `runtime.sh`                                                  | None by default; on demand with `setup-github` (fine-grained PAT strongly recommended), stored on the `opencode-config` volume                                                                        |
| API key               | VM `~/.zshenv` (`chmod 600`)                                                                               | `opencode.json` on the `opencode-config` volume (`umask 077`)                                                                                                                                         |
| MCP / skills          | Selected per project during `albert-code setup`                                                            | Global to the sandbox, added on demand (`opencode mcp add`, skills installed from their README); commands and recommendations in [mcp.md](../mcp.md) and [skills.md](../skills.md)                    |

## Adopting it

Not a target: its own maintainers are moving to [just-code](just-code.md). What it brings (per-project setup, État skills and MCP selection) is better looked for there.

## Sources

- <https://github.com/etalab-ia/albert-code> (README, commit history), checked 2026-10-09
- <https://github.com/sylvinus/agent-vm> (README, "Security" section), checked 2026-10-09
