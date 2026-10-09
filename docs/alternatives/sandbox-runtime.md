# Anthropic Sandbox Runtime (srt) and the Claude Code Bash sandbox

> [!WARNING]
> **AI-generated, not reviewed.** This page was written by an AI coding assistant ([Claude Code](https://claude.com/claude-code)) from web research on 2026-10-09. It has not been reviewed or validated by a human: check the sources before relying on it.

> **Closeness to opencode-sandbox: Medium.** Same egress idea (default deny, a proxy with a domain allowlist), but it is a per-process OS sandbox on the host, not a self-hosted container with persistent volumes and a web UI.

- **Project**: [anthropics/sandbox-runtime](https://github.com/anthropics/sandbox-runtime) (formerly `anthropic-experimental/sandbox-runtime`, which redirects), npm `@anthropic-ai/sandbox-runtime` (Apache-2.0, Anthropic)
- **Status**: "Beta Research Preview", config format may change. Release v0.0.79 on 2026-10-07, last commit 2026-10-08, about 5.5k stars, very active. The built-in Claude Code sandbox uses this package (Claude Code itself is proprietary).
- **Category**: OS-level process sandbox

## Overview

`srt` wraps any command (`srt <command>`, or `npx @anthropic-ai/sandbox-runtime <command>`) in an OS sandbox: bubblewrap on Linux, Seatbelt (`sandbox-exec`) on macOS, a dedicated local user plus a Windows Filtering Platform (WFP) egress filter on Windows (alpha). Network traffic can only reach HTTP and SOCKS5 proxies that `srt` runs on the host, which apply a domain allowlist. Claude Code uses the same package for its built-in sandbox, which only covers the shell commands Claude runs. You can also run the whole Claude Code process, or another agent, under `srt`.

## How it works

| Aspect | srt / Claude Code sandbox |
| --- | --- |
| Isolation boundary | Linux: bubblewrap namespaces (user, PID, network removed), read-only bind mounts, seccomp filter that blocks Unix socket creation (x64/arm64). macOS: Seatbelt profile. Shares the host kernel and runs as the host user. No container image. |
| Network egress | Default deny. On Linux the network namespace has no interface; traffic goes to host-side HTTP and SOCKS5 proxies through Unix sockets bridged by `socat`. On macOS Seatbelt only allows the proxy's localhost port. |
| Egress policy granularity | Domain allowlist and denylist (`allowedDomains`, `deniedDomains`, wildcards, optional `:port`). Optional per-command lists and an "ask" callback in the library. Resolved-address check blocks names that resolve to loopback, link-local or host addresses. No path or method filtering. TLS termination (`network.tlsTerminate`) is experimental and does not add content filtering. |
| Proxy bypass resistance | Strong on Linux: no network namespace, so a tool that ignores `HTTP(S)_PROXY`/`ALL_PROXY` cannot connect at all (same behaviour as our `internal` network). Non-HTTP TCP goes through SOCKS5 with the same allowlist. DNS: not resolvable inside the sandbox on Linux, per the docs (`curl --noproxy '*'` fails with "Could not resolve host"). Domain fronting is a documented bypass. |
| Credentials | Read access is allowed everywhere by default, so `~/.ssh`, `~/.aws` are readable unless denied (`denyRead`). Claude Code adds credential `deny` and `mask` entries (the proxy injects the real secret, requires TLS termination); this is a Claude Code feature, not verified to be available in plain `srt`. |
| Code / filesystem | Works on host directories. Writes denied by default except allowed paths (`allowWrite`). Built-in denies on `.git/hooks`, `.git/config`, shell rc files, `.mcp.json`, `.claude/`. On Linux the deny list is built once at launch and misses files created later (for example `git clone`). |
| Persistence | Host filesystem, nothing to persist. |
| Interfaces (CLI, web UI) | CLI wrapper and a TypeScript library (`SandboxManager`). `srt proxy` runs the proxy alone with an external decider. No web UI. |
| Supported agents (opencode?) | Any process. Documented for Claude Code and MCP servers. Running opencode under `srt` is not documented by Anthropic; a third-party blog post (July 2026) does it by allowing writes to `~/.config/opencode`, `~/.local/share/opencode`, `~/.cache/opencode`, `~/.local/state/opencode`. Not tested here. |
| Platforms / deployment | Linux (needs `bubblewrap`, `socat`, `ripgrep`; Ubuntu 24.04+ needs an AppArmor exception for user namespaces), macOS, WSL2, Windows (alpha). Inside an unprivileged Docker container it needs `enableWeakerNestedSandbox`, which "considerably weakens security". Self-hosted, no Kubernetes integration. |
| Observability | macOS: system sandbox violation log. Linux: proxy denies and seccomp events in an in-memory violation store, `--debug` logging, otherwise `strace`. No persistent access log of allowed requests documented. |

## Compared with opencode-sandbox

- **Better**:
  - No Docker: lighter, works directly on a developer laptop (Linux, macOS, WSL2).
  - Write access is deny-by-default, with built-in protection of git hooks and agent config files.
  - SOCKS5 proxy covers non-HTTP TCP (SSH, databases) with the same allowlist; we only allow ports 80/443.
  - Active project, maintained by Anthropic, used in production by Claude Code.
- **Worse or missing**:
  - Runs on the host as the host user, with the host filesystem readable by default. Our sandbox only sees its own volumes.
  - Beta research preview; config format may change.
  - No web UI, no server mode, no persistent per-request log like Squid's `access.log`.
  - Linux nesting inside Docker requires the weaker mode, so it does not combine well with our container.
  - Claude Code built-in sandbox: only shell commands are sandboxed; file tools, MCP servers and hooks run outside it, and Claude can retry unsandboxed unless `allowUnsandboxedCommands: false`.
- **Same idea**:
  - Default-deny egress through a proxy with a domain allowlist, no TLS interception by default.
  - The sandboxed process has no direct route out, so ignoring proxy variables only breaks the tool (see [networking.md](../networking.md)).
  - Same documented risk with broad domains such as `github.com`, and domain fronting.

## Adopting it

Not a replacement: `srt` is a building block for a laptop, not a self-hosted sandbox. Switching would lose the web mode ([web-mode.md](../web-mode.md)), the isolation of code and credentials in volumes, the Kubernetes path ([portability.md](../portability.md)) and the Squid audit log. It stays model-agnostic and could wrap opencode, but that is not documented upstream. A possible use: run `srt` (or its `srt proxy` mode) as a lighter "local mode" next to this project, or borrow its write-deny defaults. Contributing an opencode example upstream is possible (Apache-2.0).

## Sources

Checked 2026-10-09.

- [anthropics/sandbox-runtime README](https://github.com/anthropics/sandbox-runtime) and [releases](https://github.com/anthropics/sandbox-runtime/releases)
- [Claude Code: Configure the sandboxed Bash tool](https://code.claude.com/docs/en/sandboxing)
- [Claude Code: Choose a sandbox environment](https://code.claude.com/docs/en/sandbox-environments)
- [Anthropic engineering: Beyond permission prompts](https://www.anthropic.com/engineering/claude-code-sandboxing)
- [Sandboxing opencode with bubblewrap and srt](https://blog.guillaumea.fr/post/sandboxing-opencode-ai-agents-bubblewrap-srt/) (third-party blog, July 2026)
