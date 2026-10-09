# jail

> [!WARNING]
> **AI-generated, not reviewed.** This page was written by an AI coding assistant ([Claude Code](https://claude.com/claude-code)) from web research on 2026-10-09. It has not been reviewed or validated by a human: check the sources before relying on it.

> **Closeness to agent-sandbox: Medium.** Same tool stack (Docker + opencode, web UI included), but no network filtering and the host project and opencode credentials are bind-mounted into the container.

- **Project**: <https://github.com/gstamp/jail> (README says MIT, but the repository has no `LICENSE` file and GitHub detects no license; single maintainer, Glen Stampoultzis)
- **Status**: personal project, 21 commits, no releases, last commit 2026-01-16, 1 star (checked 2026-10-09). Looks inactive.
- **Category**: opencode wrapper

## Overview

`jail` is a ~530-line Bash script that builds a per-project Docker image from a `Dockerfile.jail` and runs opencode in it. The goal is to let opencode run commands without confirmation prompts: the script injects a permission override that allows every `bash` command. It also starts the opencode web UI (`jail web`). It protects the host filesystem outside the project, not the network.

## How it works

| Aspect | jail |
| --- | --- |
| Isolation boundary | Docker container sharing the host kernel. Runs as the host UID/GID (`--user`). No extra hardening flags (no `--cap-drop`, no `--read-only`, no seccomp profile changes). |
| Network egress | Unrestricted. The CLI mode uses `--network host` (the container shares the host network stack, including services bound to `127.0.0.1`). The web mode uses the default bridge network. |
| Egress policy granularity | None. |
| Proxy bypass resistance | Not applicable: there is no proxy or firewall. |
| Credentials | Host `~/.config/opencode` and `~/.local/share/opencode` (where opencode stores `auth.json`) are mounted read-write, `~/.gitconfig` read-only. `OPENROUTER_API_KEY`, `JIRA_API_TOKEN`, `MXBAI_API_KEY` are passed as environment variables. mgrep credentials are mounted if present. All are readable by the agent. |
| Code / filesystem | Current host directory bind-mounted read-write at `/workspace`. |
| Persistence | Host directories (config and session history are shared with the host opencode install). The container itself is `--rm`. |
| Interfaces (CLI, web UI) | CLI (`jail`, `jail bash`, `jail <cmd>`). Web UI (`jail web`, `opencode web` on 127.0.0.1:7500, `--public` binds 0.0.0.0). No authentication is configured by the script. |
| Supported agents (opencode?) | opencode only (the script is built around opencode config and paths). Model provider is whatever the host opencode config uses. |
| Platforms / deployment | Any host with Docker and Bash (Linux, macOS). Local use; no server or Kubernetes deployment. |
| Observability | None beyond `docker logs`. |

## Compared with agent-sandbox

- **Better**:
  - Very small and easy to read (one script).
  - Per-project `Dockerfile.jail` to add toolchains (Go, Rust, Python, Java blocks provided).
  - Works directly on the host checkout: no copy back to the host.
  - Several web UI instances in parallel (automatic port selection).
- **Worse or missing**:
  - No network filtering at all, and `--network host` in CLI mode removes even network namespace isolation ([../networking.md](../networking.md)).
  - Host opencode credentials and history are mounted read-write: a compromised agent can read or alter them.
  - Host project is mounted read-write: the agent can modify `.git/hooks` or other files that later run on the host.
  - Web UI has no password; `--public` exposes it unauthenticated ([../web-mode.md](../web-mode.md)).
  - No request logging, no hardening guidance ([../docker-hardening.md](../docker-hardening.md)).
  - No license file, no releases, apparently unmaintained.
- **Same idea**:
  - Docker container as the isolation boundary, opencode as the agent.
  - Non-root user inside the container.
  - `opencode web` exposed on localhost.

## Adopting it

Not a replacement. Adopting jail would lose the egress allowlist, request logs, web UI authentication and the credential separation from the host. It targets a different threat (destructive commands on the host filesystem), not exfiltration. Contributing is possible in principle, but the project has a single maintainer, no license file and no activity since January 2026. The useful idea to borrow is the per-project Dockerfile with optional toolchain blocks.

## Sources

- Repository and README: <https://github.com/gstamp/jail> (checked 2026-10-09)
- Script source, `docker run` flags: <https://github.com/gstamp/jail/blob/main/jail>
- Permission override: <https://github.com/gstamp/jail/blob/main/jail-permissions.json>
