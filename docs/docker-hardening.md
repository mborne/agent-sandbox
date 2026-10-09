# Docker hardening

The sandbox restricts what the agent can **reach on the network**. It does not protect the **host** on its own: the `sandbox` container shares the host kernel and depends on the Docker daemon, which runs as root by default. A kernel exploit, a container escape or a misconfigured daemon gives the agent (or code it runs) access to the host.

Host security therefore relies on a hardened Docker configuration. This page lists the main tools to audit it and the main settings to apply. It is a starting point, not a complete guide.

## Audit tools

| Tool                                                                         | What it checks                                                                                                                                                           |
| ---------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| [Docker Bench for Security](https://github.com/docker/docker-bench-security) | Host, daemon, images and running containers against the [CIS Docker Benchmark](https://www.cisecurity.org/benchmark/docker). Run it on the host after any daemon change. |
| [Lynis](https://cisofy.com/lynis/)                                           | General host hardening (kernel, SSH, updates, auditd…), with a section on containers.                                                                                    |
| [Trivy](https://trivy.dev)                                                   | Vulnerabilities in images (`trivy image`) and misconfigurations in `compose.yaml` / Dockerfiles (`trivy config .`).                                                      |
| [Dockle](https://github.com/goodwithtech/dockle)                             | Image best practices (non-root user, secrets in layers, …).                                                                                                              |

Run Docker Bench for Security from a clone of its repository:

```bash
git clone https://github.com/docker/docker-bench-security.git
cd docker-bench-security
sudo sh docker-bench-security.sh
```

Each `[WARN]` line references a CIS control. Not all of them apply to a workstation, but the daemon section (`2.x`) should be reviewed carefully.

## Main settings

### Daemon (`/etc/docker/daemon.json`)

- **User namespace remapping** (`"userns-remap": "default"`): root in a container is mapped to an unprivileged UID range on the host (`/etc/subuid`, `/etc/subgid`), so an escape no longer lands as host root. See [Isolate containers with a user namespace](https://docs.docker.com/engine/security/userns-remap/). Caveats:
  - Images and volumes live under a separate directory (`/var/lib/docker/<uid>.<gid>`): rebuild the stack and recreate the volumes after enabling it.
  - Files in volumes are owned by shifted UIDs on the host (the `ubuntu` user, uid 1000, becomes e.g. 101000).
  - `--privileged` and `--userns=host` containers need an explicit opt-out.
- **No new privileges by default** (`"no-new-privileges": true`): setuid binaries cannot raise privileges inside containers.
- **Live restore** (`"live-restore": true`): containers keep running while the daemon is restarted for updates.
- **Keep the default seccomp and AppArmor/SELinux profiles** enabled; never start containers with `seccomp=unconfined` or `apparmor=unconfined`.

Example:

```json
{
  "userns-remap": "default",
  "no-new-privileges": true,
  "live-restore": true
}
```

Restart the daemon (`sudo systemctl restart docker`) and run Docker Bench for Security again.

### Rootless mode

[Rootless Docker](https://docs.docker.com/engine/security/rootless/) runs the daemon itself as an unprivileged user. It goes further than `userns-remap` (a daemon compromise is not host root) at the cost of some limitations (networking performance, cgroup support depending on the distribution).

### Daemon access

- **Never mount the Docker socket** (`/var/run/docker.sock`) into the sandbox: it is equivalent to root on the host.
- Membership of the `docker` group is equivalent to root: keep it to the users who need it.
- Do not expose the daemon on TCP without TLS client authentication.

### Containers

The stack does not grant extra privileges (no `privileged`, no host network, no host bind mount for the sandbox). These options, not set by [compose.yaml](../compose.yaml), further reduce the attack surface of the `sandbox` service:

- `cap_drop: [ALL]`: the agent runs as an unprivileged user and needs no Linux capability.
- `security_opt: [no-new-privileges:true]` if not set at the daemon level.
- `pids_limit`, `mem_limit`, `cpus`: limit the impact of a runaway process (fork bomb, memory exhaustion).

### Host

- Keep the kernel and Docker Engine up to date: container escapes usually exploit kernel or runtime vulnerabilities.
- For stronger isolation, run the stack in a dedicated virtual machine, or use a sandboxed runtime such as [gVisor](https://gvisor.dev) (`runsc`) or [Kata Containers](https://katacontainers.io).
- Audit the daemon with `auditd` (rules on `/usr/bin/dockerd`, `/var/lib/docker`, `/etc/docker`), as recommended by the CIS benchmark.

## References

- [Docker Engine security](https://docs.docker.com/engine/security/)
- [CIS Docker Benchmark](https://www.cisecurity.org/benchmark/docker)
- ANSSI, [Recommandations de sécurité relatives au déploiement de conteneurs Docker](https://cyber.gouv.fr/publications/recommandations-de-securite-relatives-au-deploiement-de-conteneurs-docker)
- [OWASP Docker Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html)

None of these domains are needed by the sandbox: they are read from the host and are not in [squid/allowed-domains.txt](../squid/allowed-domains.txt).
