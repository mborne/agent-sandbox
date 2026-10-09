# OpenAI Codex CLI sandbox

> [!WARNING]
> **AI-generated, not reviewed.** This page was written by an AI coding assistant ([Claude Code](https://claude.com/claude-code)) from web research on 2026-10-09. It has not been reviewed or validated by a human: check the sources before relying on it.

> **Closeness to opencode-sandbox: Low.** A per-command OS sandbox built into the Codex agent, with an optional domain-filtering proxy; it is not a standalone self-hosted environment and is tied to Codex.

- **Project**: [openai/codex](https://github.com/openai/codex) (Apache-2.0, OpenAI). Sandbox code in `codex-rs/linux-sandbox`, `codex-rs/network-proxy`, `codex-rs/windows-sandbox-rs`.
- **Status**: Very active. Stable release `rust-v0.162.0` on 2026-10-08, alpha releases several times a day, about 128k stars.
- **Category**: OS-level process sandbox

## Overview

Codex runs every model-generated command inside an OS sandbox chosen by `sandbox_mode`: `read-only`, `workspace-write` (default for local work) or `danger-full-access`. Linux uses bubblewrap plus seccomp (Landlock is now a legacy option, rejected for filesystem-restricted policies), macOS uses Seatbelt, Windows uses MXC or legacy elevated/unelevated modes. Network is off by default. When enabled, the optional `network_proxy` feature routes traffic through a local HTTP/SOCKS5 proxy with a domain allowlist.

## How it works

| Aspect | Codex CLI sandbox |
| --- | --- |
| Isolation boundary | Per command. Linux: `bwrap` with `--unshare-user`, `--unshare-pid`, `--ro-bind / /`, writable roots bound read-write, `PR_SET_NO_NEW_PRIVS` and a seccomp network filter. Host kernel, host user. The Codex process itself is not sandboxed. |
| Network egress | Off by default in `workspace-write` (`--unshare-net`). `sandbox_workspace_write.network_access = true` turns it on, unrestricted unless `features.network_proxy` is also on. |
| Egress policy granularity | With `network_proxy`: domain allow/deny (`*.x`, `**.x`, `?`), deny wins, local/private ranges blocked, best-effort DNS rebinding check. `mode = "limited"` allows only GET/HEAD/OPTIONS and uses TLS interception (MITM) with a Codex CA. MITM hooks can match host, method and path and strip headers. |
| Proxy bypass resistance | In managed proxy mode on Linux, the command has no network namespace and a TCP-to-Unix-socket bridge reaches only the proxy; seccomp then blocks new Unix sockets. So ignoring proxy variables does not bypass it. Without `network_proxy`, enabled network is direct and unfiltered. |
| Credentials | Codex credentials live in `~/.codex` on the host. The proxy does not filter the model and auth requests of Codex itself, nor MCP servers, web search or connectors. |
| Code / filesystem | Host workspace, writable roots configurable; `.git`, `gitdir:` targets and `.codex` stay read-only; glob-based unreadable paths (for example `**/*.env`). |
| Persistence | Host filesystem. |
| Interfaces (CLI, web UI) | Codex TUI, `codex exec`, IDE extension, desktop app. `codex sandbox linux [COMMAND]...` (also `macos`, `windows`) runs an arbitrary command under the sandbox. No self-hosted web UI. |
| Supported agents (opencode?) | Codex only. `codex sandbox linux -- opencode` should technically work: the source starts the managed network proxy for the child process when the profile defines network rules. Not documented as a supported use and not tested. Requires installing Codex and its `config.toml`. |
| Platforms / deployment | Linux (bubblewrap; system `bwrap` or bundled helper; needs unprivileged user namespaces), macOS, Windows, WSL2 (not WSL1). In Docker the sandbox "may not work"; OpenAI recommends container isolation plus `--sandbox danger-full-access`. Cloud variant: Codex Cloud (SaaS). |
| Observability | Proxy returns `403` with an `x-proxy-error` header. OTEL audit events `codex.network_proxy.policy_decision` (opt-in OTel export). `codex sandbox macos --log-denials`. |

## Compared with opencode-sandbox

- **Better**:
  - Finer egress policy: method-limited mode, MITM hooks on host, method and path.
  - SOCKS5 for non-HTTP traffic, private-range blocking and DNS rebinding check.
  - Write protection of `.git` and `.codex` even inside writable roots.
  - Mature, very active, used by a large user base.
- **Worse or missing**:
  - Tied to Codex: the policy lives in Codex `config.toml`, and the sandbox is a CLI subcommand of Codex.
  - Sandbox wraps commands only. Codex itself, MCP servers and web search are outside the network policy.
  - Host filesystem and host user; no separation of credentials from the agent.
  - Escalation to unsandboxed execution is part of the approval flow (`danger-full-access`, `--dangerously-bypass-approvals-and-sandbox`).
  - Does not nest well in Docker, which is our deployment model.
  - No web UI to self-host.
- **Same idea**:
  - Default-deny network, domain allowlist enforced by a proxy, no route out except through the proxy.
  - Codex's reference devcontainer (linked from the docs) also uses a firewall allowlist. The `.devcontainer` folder returned 404 on `main` on 2026-10-09 (not verified elsewhere).

## Adopting it

Not a realistic switch: adopting it means adopting Codex as the agent, which loses opencode, the web mode, model agnosticism outside what Codex supports, and the self-hosted server model. What is reusable: `codex-network-proxy` is a separate Rust crate with a standalone JSON config and a library API (`cargo run -p codex-network-proxy -- --config ...`). It is a possible Squid replacement if we need method/path rules, at the cost of a TLS-intercepting CA. Prebuilt standalone binaries for the proxy: not verified.

## Sources

Checked 2026-10-09.

- [Agent approvals & security](https://developers.openai.com/codex/agent-approvals-security) (redirects to learn.chatgpt.com; markdown version at `/codex/agent-approvals-security.md`)
- [openai/codex repository](https://github.com/openai/codex) and [releases](https://github.com/openai/codex/releases)
- [codex-rs/linux-sandbox/README.md](https://github.com/openai/codex/blob/main/codex-rs/linux-sandbox/README.md)
- [codex-rs/network-proxy/README.md](https://github.com/openai/codex/blob/main/codex-rs/network-proxy/README.md)
- [codex-rs/cli/src/debug_sandbox.rs](https://github.com/openai/codex/blob/main/codex-rs/cli/src/debug_sandbox.rs) (managed proxy started for `codex sandbox`)
