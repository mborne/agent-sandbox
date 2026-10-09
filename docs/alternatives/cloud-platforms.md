# Cloud sandbox platforms

> [!WARNING]
> **AI-generated, not reviewed.** This page was written by an AI coding assistant ([Claude Code](https://claude.com/claude-code)) from web research on 2026-10-09. It has not been reviewed or validated by a human: check the sources before relying on it.

> **Closeness to agent-sandbox: Low.** These are APIs to create isolated VMs or containers on demand; several now have domain egress allowlists and secret injection stronger than ours, but none is a ready self-hosted opencode environment, and all but E2B depend on a SaaS control plane.

- **Project**: E2B, Daytona, Modal, Vercel Sandbox, Cloudflare Sandbox, Northflank, Deno Sandbox (links below; licenses per row)
- **Status**: all commercial services in active development, except the open-source Daytona repository, archived after the June 2026 move to a private codebase (checked 2026-10-09).
- **Category**: Cloud sandbox platform

## Overview

These platforms give a program (usually an agent backend) an SDK to start a sandbox, run commands, move files and expose ports. Isolation is a microVM (Firecracker, Cloud Hypervisor) or gVisor, so the kernel is not shared with other tenants. Most added egress policies in 2026, often by SNI inspection, and some inject credentials outside the sandbox. Running opencode in them means writing glue code (or following a vendor guide), and paying per use.

## How it works

| Platform | Isolation | Egress control | Self-hostable | Open source | opencode support |
| --- | --- | --- | --- | --- | --- |
| [E2B](https://e2b.dev) | Firecracker microVM | On by default. `allowInternetAccess: false`, or `allowOut`/`denyOut` with IPs, CIDRs and domains. Domains only for HTTP port 80 (Host header) and TLS port 443 (SNI); no QUIC; UDP DNS to 8.8.8.8 allowed automatically. | Partly: [E2B Embed](https://github.com/e2b-dev/infra/tree/main/embed) runs the whole stack on one Linux host with KVM via Docker Compose (also Terraform for GCP and a Kubernetes manifest), but the README calls it an evaluation package; production self-hosting is the Enterprise offer. | Yes, Apache-2.0 (SDK and infra) | Prebuilt `opencode` template; CLI or `opencode serve` on port 4096. Keys passed as env vars (visible to the agent). |
| [Daytona](https://www.daytona.io) | Containers on Daytona runners (exact technology not verified) | `networkBlockAll`, `networkAllowList` (max 10 IPv4 CIDRs), `domainAllowList` (max 100 domains, `*.` wildcards). Low tiers cannot override the org policy. | Formerly. The public repo is archived and frozen at v0.190.0 (AGPL-3.0); development moved to a private codebase in June 2026. | No longer (frozen AGPL-3.0 snapshot only) | Official `@daytona/opencode` plugin (tools run in the sandbox, git sync to `opencode/<N>` branches) and guides for opencode server / web in a sandbox. |
| [Modal](https://modal.com) | gVisor | `block_network`, `outbound_cidr_allowlist` (any protocol), `outbound_domain_allowlist` (beta, TLS port 443 only, SNI match). Inbound tunnels restricted with `inbound_cidr_allowlist`. | No | SDK only (Apache-2.0); platform proprietary | No official guide found (not verified). |
| [Vercel Sandbox](https://vercel.com/docs/sandbox) | Firecracker microVM | `allow-all` (default), `deny-all` (incl. DNS), or allowlist of domains (SNI, wildcards) and CIDRs; updatable at runtime. Credential brokering: TLS terminated with a per-sandbox CA only for domains with `transform`/`forwardURL` rules, which inject headers or forward to your proxy. Docs warn about domain fronting. | No | SDK/CLI repo Apache-2.0; platform proprietary | Official guide (March 2026): opencode server on port 4096, basic auth, egress limited to AI Gateway, key injected by the firewall. |
| [Cloudflare Sandbox](https://developers.cloudflare.com/sandbox/) | Firecracker microVM per container instance | Internet on by default; `allowedHosts`/`deniedHosts` (glob), `enableInternet = false`. HTTP and, if `interceptHttps` is set, HTTPS (ephemeral CA) go through Worker `outbound` handlers that can add secrets. Ports other than 80/443 never reach handlers; DNS goes to Cloudflare. | No | SDK Apache-2.0 ([cloudflare/sandbox-sdk](https://github.com/cloudflare/sandbox-sdk), v1.0.0 on 2026-10-08); platform proprietary | Official guide: opencode in a sandbox driven by a Worker/Durable Object REST API, egress limited to AI Gateway and `github.com`, gateway token added by the Worker. No web UI in the guide. |
| [Northflank](https://northflank.com) | Kata Containers (Cloud Hypervisor), gVisor or Firecracker depending on workload | Network policies with egress allowlists by IP, CIDR, FQDN or hostname; default allow until a rule is added. Documented for BYOC clusters (managed cloud not verified). | Partly: BYOC runs workloads in your AWS/GCP/Azure/on-prem cluster, control plane stays SaaS | No | No guide found (not verified). |
| [Deno Sandbox](https://docs.deno.com/sandbox/) | Linux microVM on Deno Deploy | `allowNet` host list enforced by an outbound proxy at the VM boundary; secrets appear as placeholders and are substituted only on requests to approved hosts. | No | No (SDK license not verified) | No guide found (not verified). Max lifetime 30 min at launch (Feb 2026). |

## Compared with agent-sandbox

- **Better**:
  - Kernel isolation (microVM or gVisor) instead of a container sharing the host kernel ([../docker-hardening.md](../docker-hardening.md)).
  - Vercel, Cloudflare and Deno keep secrets out of the sandbox (injected at the egress layer); agent-sandbox stores them where the agent can read them.
  - Egress is enforced at the network layer (no reliance on `HTTP(S)_PROXY`), with runtime policy updates and, for Vercel, `deny-all` including DNS.
  - Ephemeral sandboxes, snapshots, scaling to many parallel sessions.
- **Worse or missing**:
  - SaaS: code, prompts and data leave the organisation; usage-based pricing; vendor lock-in. Only E2B publishes its full stack; its single-host Docker Compose package (needs KVM) is labelled evaluation-only.
  - No per-request log like Squid's access log out of the box (not verified for each platform).
  - SNI-only domain filters share Squid's limit (per domain, no path) and add domain fronting caveats; plain HTTP or non-443 ports often need CIDR rules.
  - None ships a ready, persistent, password-protected opencode workspace; each needs glue code (only Vercel's guide comes close, with basic auth).
  - Daytona: no longer open source, self-hosting means a frozen AGPL snapshot.
- **Same idea**:
  - Default-deny allowlists by domain (E2B, Daytona, Modal, Vercel, Cloudflare, Northflank, Deno) match the Squid allowlist ([../networking.md](../networking.md)).
  - opencode server inside the sandbox with an authenticated web UI (Vercel, E2B, Daytona guides) matches [../web-mode.md](../web-mode.md).

## Adopting it

Only if SaaS is acceptable. Then Vercel Sandbox or Cloudflare Sandbox offer the closest security model (domain allowlist plus secrets outside the sandbox), with an official opencode guide; the owner would lose self-hosting on a Linux server, the Squid logs, model choice beyond what the gateway proxies (Cloudflare's guide is built around AI Gateway and Anthropic), and the Kubernetes path. For a self-hosted option, E2B is the only open-source full stack (Firecracker, Postgres, Redis, ClickHouse); its single-host package is for evaluation, so production use means operating that stack or buying Enterprise. Daytona is no longer a safe open-source bet. None of these replaces agent-sandbox as is; they are execution backends to build on.

## Sources

All checked 2026-10-09.

- E2B internet access: <https://docs.e2b.dev/network/internet-access>; opencode: <https://docs.e2b.dev/agents/opencode>; infra: <https://github.com/e2b-dev/infra>
- Daytona archived repo: <https://github.com/daytonaio/daytona>; network limits: <https://www.daytona.io/docs/en/network-limits/>; opencode plugin: <https://www.daytona.io/docs/en/guides/opencode/opencode-plugin>
- Daytona closing source (third-party analysis): <https://bex.co/blog/2026/09/09/daytona-closed-source-self-hostable-meaning>
- Modal networking: <https://modal.com/docs/guide/sandbox-networking>
- Vercel firewall: <https://vercel.com/docs/sandbox/concepts/firewall>; opencode guide: <https://examples.vercel.com/kb/guide/running-opencode-securely-with-the-vercel-sandbox>
- Cloudflare opencode: <https://developers.cloudflare.com/sandbox/coding-agents/opencode/>; outbound traffic: <https://developers.cloudflare.com/sandbox/guides/outbound-traffic/>; architecture: <https://developers.cloudflare.com/containers/platform-details/architecture/>
- Northflank network policies: <https://northflank.com/docs/v1/application/network/configure-network-policies>; isolation: <https://northflank.com/blog/best-cloud-sandboxes>
- Deno Sandbox: <https://docs.deno.com/sandbox/>, <https://deno.com/blog/introducing-deno-sandbox>
