# opencode-cloud

> [!WARNING]
> **AI-generated, not reviewed.** This page was written by an AI coding assistant ([Claude Code](https://claude.com/claude-code)) from web research on 2026-10-09. It has not been reviewed or validated by a human: check the sources before relying on it.

> **Closeness to opencode-sandbox: Medium.** Same shape (opencode in a long-lived Docker container, named volumes, authenticated web UI, self-hosted), but no egress filtering and it ships a fork of opencode that stopped tracking upstream in February 2026.

- **Project**: <https://github.com/pRizz/opencode-cloud> (MIT, single maintainer pRizz; mirror on gitea.com)
- **Status**: README says "work in progress", "expect breaking changes". Last release `v25.1.3` on 2026-02-12, last commit on `main` 2026-02-21; only bot branches (dependency updates) since. The bundled opencode fork (<https://github.com/pRizz/opencode>) was last pushed 2026-02-21. 20 stars (checked 2026-10-09).
- **Category**: opencode wrapper

## Overview

opencode-cloud runs a fork of opencode as a persistent service in a Docker container (`prizz/opencode-cloud-sandbox`). The fork adds passkey (WebAuthn) login, username/password with TOTP 2FA, and several users on one instance. A Rust CLI (`occ`, distributed through cargo and npm) manages the container lifecycle, systemd/launchd service, bind mounts and updates. Deployment helpers exist for Docker Compose, AWS (CloudFormation), Railway and DigitalOcean.

## How it works

| Aspect | opencode-cloud |
| --- | --- |
| Isolation boundary | Docker container sharing the host kernel. User `opencoder` has passwordless `sudo` inside the container. Default mode adds `SETUID`/`SETGID` capabilities; the optional systemd mode runs `--privileged` with the host cgroup namespace and `/sys/fs/cgroup` mounted read-write. |
| Network egress | Unrestricted (default Docker bridge network). No proxy, firewall or allowlist found in the compose file, the CLI or the image. |
| Egress policy granularity | None. Network "security" in the docs is about inbound exposure (bind to 127.0.0.1 by default, cloud firewalls, ALB/TLS on AWS). |
| Proxy bypass resistance | Not applicable: there is no egress control. |
| Credentials | Provider keys and opencode auth in the `opencode-config` / `opencode-data` volumes, an `opencode-ssh` volume for SSH keys. All readable by the agent (and by any user with the container's `sudo`). |
| Code / filesystem | `opencode-workspace` named volume by default; `occ mount add` bind-mounts host directories. |
| Persistence | Seven named volumes (data, state, cache, workspace, config, users, ssh). |
| Interfaces (CLI, web UI) | Web UI on 127.0.0.1:3000 with passkey / password + TOTP auth and a one-time bootstrap password. `occ` CLI for lifecycle, users, logs. Optional Cockpit console (currently disabled in the image). |
| Supported agents (opencode?) | Its own opencode fork only. Model provider: whatever opencode supports (not specifically tested). |
| Platforms / deployment | Linux and macOS hosts with Docker; Docker Desktop; AWS CloudFormation (EC2 behind ALB, HTTPS); Railway; DigitalOcean droplet. No Kubernetes manifests found. |
| Observability | Container logs (`occ logs`, json-file driver with rotation). No egress or request log. |

## Compared with opencode-sandbox

- **Better**:
  - Stronger web authentication: passkeys, TOTP 2FA, several users on one instance.
  - Packaged releases (Docker Hub, GHCR, crates.io, npm) and one-command deployment scripts, including AWS with TLS.
  - Service integration (systemd/launchd) and an update flow.
  - Large prebuilt image with many toolchains.
- **Worse or missing**:
  - No egress control at all: the core of opencode-sandbox ([../networking.md](../networking.md)) is absent.
  - Weaker container: passwordless `sudo`, extra capabilities, `--privileged` in systemd mode ([../docker-hardening.md](../docker-hardening.md)).
  - Runs a fork of opencode frozen since February 2026; upstream opencode features and fixes since then are missing.
  - Much larger code base (Rust CLI, Node CLI, fork as submodule, 1000+ commits) for one maintainer; activity stopped after February 2026.
  - Only opencode (its fork); no documented path to other agents.
- **Same idea**:
  - opencode in a Docker container with named volumes for workspace and config.
  - Web UI bound to localhost, reached through an SSH tunnel on a remote server ([../web-mode.md](../web-mode.md)).
  - Self-hosted on any Linux Docker host, MIT license.

## Adopting it

Not a good base. Switching would lose the domain allowlist and request logging, and tie the owner to a stale opencode fork. Adding egress filtering would mean a Squid sidecar and an `internal` network in its compose file plus changes in the Rust CLI that creates containers. The passkey/2FA web login is the part worth watching; for opencode-sandbox, the nginx relay could gain stronger auth without the fork.

## Sources

- Repository, README, `docker-compose.yml`: <https://github.com/pRizz/opencode-cloud> (checked 2026-10-09)
- Container creation (capabilities, privileged systemd mode): <https://github.com/pRizz/opencode-cloud/blob/main/packages/core/src/docker/container.rs>
- Image (`sudo` setup): <https://github.com/pRizz/opencode-cloud/blob/main/packages/core/src/docker/Dockerfile>
- Releases: <https://github.com/pRizz/opencode-cloud/releases>
- opencode fork: <https://github.com/pRizz/opencode>
