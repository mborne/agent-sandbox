# opencode-sandbox (opencode plugin)

> [!WARNING]
> **AI-generated, not reviewed.** This page was written by an AI coding assistant ([Claude Code](https://claude.com/claude-code)) from web research on 2026-10-09. It has not been reviewed or validated by a human: check the sources before relying on it.

> **Closeness to agent-sandbox: Low.** Only the agent's tools run in a sandbox; opencode itself, its credentials and its web access stay on the host, and the sandbox has no egress filtering.

- **Project**: <https://github.com/thisisryanswift/opencode-sandbox> (Apache-2.0 per README and `package.json`, but no `LICENSE` file and GitHub detects none; single maintainer, Ryan Swift)
- **Status**: prototype. 3 commits, all on 2026-03-01 (last one "Stashing, done for the day"), version 0.1.0, not published to npm, no releases, 0 stars. Open tickets for end-to-end tests of the E2B and Sprites providers (checked 2026-10-09).
- **Category**: opencode wrapper

## Overview

An opencode plugin that replaces the built-in `bash`, `read`, `write`, `edit`, `multiedit`, `ls`, `glob` and `grep` tools with versions that run in a per-session sandbox. Providers: Daytona, E2B, Sprites (Fly.io) or local Docker (default, also Podman). The project files are copied into the sandbox (respecting `.gitignore`), and changes come back to the host as git branches `opencode/<N>` when the session goes idle. The design is the same as Daytona's official plugin (`@daytona/opencode`), extended to more providers.

## How it works

| Aspect | opencode-sandbox plugin |
| --- | --- |
| Isolation boundary | Depends on the provider: Docker container on the host (`docker run -d <image> sleep infinity`, default image `ubuntu:22.04`, no hardening flags), or the remote provider's VM/container. The opencode process itself is not sandboxed. |
| Network egress | Sandbox: unrestricted (default Docker bridge; provider defaults for cloud). Host-side opencode (LLM calls, `webfetch`, MCP servers) has whatever the host has. |
| Egress policy granularity | None configured by the plugin. Provider features (e.g. E2B allow lists) are not exposed. |
| Proxy bypass resistance | Not applicable: no egress control. |
| Credentials | Provider API keys and LLM keys stay in the host environment, out of the sandbox. Git-ignored files (`.env`) are not copied. |
| Code / filesystem | Host repository copied into `/workspace` in the sandbox; changes synced back via git (SSH for Daytona, `exec` for the others) to local branches. |
| Persistence | Ephemeral sandbox per session, removed when the session ends. History stays in the host opencode. |
| Interfaces (CLI, web UI) | Whatever opencode offers on the host (TUI, `opencode web`); `getPreviewURL` tool for ports exposed by the sandbox. |
| Supported agents (opencode?) | opencode only (it is an opencode plugin, pinned to `@opencode-ai/plugin` 1.2.15). |
| Platforms / deployment | Host with Bun/opencode; Docker or Podman locally, or SaaS accounts (Daytona, E2B, Sprites). |
| Observability | Plugin logger and TUI toasts (toasts reported as not working in an open ticket). |

## Compared with agent-sandbox

- **Better**:
  - Secrets never enter the sandbox: LLM keys and provider tokens stay with the host opencode process.
  - Git-ignored files are not exposed to the agent's tools.
  - Can offload execution to cloud microVMs (E2B, Sprites, Daytona) for kernel-level isolation.
  - Changes land as reviewable local git branches.
- **Worse or missing**:
  - The agent process runs on the host: `webfetch`, MCP servers and any tool not overridden by the plugin are not sandboxed.
  - No network filtering in the sandbox: data copied into it can be sent anywhere ([../networking.md](../networking.md)).
  - Default Docker provider has no hardening ([../docker-hardening.md](../docker-hardening.md)).
  - Prototype, untested providers, no license file, no activity since March 2026.
  - No server/web deployment story ([../web-mode.md](../web-mode.md)); not portable to other agents.
- **Same idea**:
  - opencode as the agent, Docker as the default local backend.
  - Work on a copy of the repository, not on the live host checkout.

## Adopting it

Not as a replacement. It solves a different problem (keep secrets and the host filesystem away from the agent's shell) and leaves exfiltration through the network open, both from the sandbox and from the host-side opencode. If the plugin approach is of interest, the maintained reference is Daytona's own `@daytona/opencode` plugin (Daytona only). The "secrets outside the sandbox" idea is worth noting for agent-sandbox, where credentials are readable by the agent.

## Sources

- Repository, README, `package.json`, `.tickets/`: <https://github.com/thisisryanswift/opencode-sandbox> (checked 2026-10-09)
- Docker provider: <https://github.com/thisisryanswift/opencode-sandbox/blob/main/.opencode/plugin/sandbox/providers/docker.ts>
- Daytona opencode plugin: <https://www.daytona.io/docs/en/guides/opencode/opencode-plugin>
