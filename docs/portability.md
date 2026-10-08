# Portability

The sandbox relies on a simple principle: **the agent has no route to the Internet, its only way out is a proxy that filters domains**. Nothing in it is specific to opencode or to Docker Compose:

- an isolated network with no gateway (`internal: true` here);
- a Squid proxy attached to both sides, with a domain allowlist ([squid/squid.conf](../squid/squid.conf), [squid/allowed-domains.txt](../squid/allowed-domains.txt));
- `HTTP(S)_PROXY` variables so that tools use the proxy, tools that ignore them simply fail to connect;
- persistent volumes for configuration and code.

This page describes two ways to reuse it: running another coding agent, and moving to Kubernetes. Neither is implemented in this repository.

## Other coding agents

### Checklist

To run another agent (Claude Code, Codex CLI, Gemini CLI, Aider…) in the same sandbox:

1. **Install it** in [opencode/Dockerfile](../opencode/Dockerfile). The build runs outside the sandbox network, so install scripts and package registries are reachable at that point.
2. **Allow its domains** in [squid/allowed-domains.txt](../squid/allowed-domains.txt): the model API and, if it uses one, the login endpoint. Telemetry or update domains can stay denied; the agent should keep working without them. Watch `docker compose logs -f proxy` for `TCP_DENIED` on the first runs to find what is missing.
3. **Check proxy support**: the agent must honor `HTTPS_PROXY`. Node.js-based agents also need `NODE_USE_ENV_PROXY=1`, already set in [compose.yaml](../compose.yaml).
4. **Persist its configuration**: only `~/.config`, `~/.local` and `~/workspace` are on named volumes. An agent that stores credentials elsewhere (for example `~/.claude`) needs an extra volume or a variable pointing to one of these directories.

### Claude Code

[Claude Code](https://docs.claude.com/en/docs/claude-code/overview) fits without network changes: `.anthropic.com` (API) and `.claude.ai` (login) are already in [squid/allowed-domains.txt](../squid/allowed-domains.txt), and it honors `HTTPS_PROXY`.

- Install: `npm install -g @anthropic-ai/claude-code` as root in the Dockerfile (before `USER ubuntu`).
- Configuration: stored in `~/.claude` and `~/.claude.json` by default. Set `CLAUDE_CONFIG_DIR=/home/ubuntu/.config/claude` in [compose.yaml](../compose.yaml) to keep it on the `opencode-config` volume.
- Run: `docker compose exec sandbox claude`.

### Other agents

Their domains are **not** in the allowlist. For example, an agent using the OpenAI API needs `api.openai.com`, one using the Gemini API needs `generativelanguage.googleapis.com`. Add only what the agent actually uses, and document why in the allowlist.

## Kubernetes, web mode

The same architecture maps to Kubernetes, with the agent exposed through a web UI instead of `docker compose exec` (opencode provides `opencode web` / `opencode serve`). This makes the sandbox usable from a browser, one pod per user, without Docker on the user's machine.

### Mapping

| Docker Compose | Kubernetes |
| -------------- | ---------- |
| `sandbox` service | Deployment (or StatefulSet) running `opencode web`, exposed through a Service and an Ingress |
| `proxy` service | Deployment running Squid, Service on port 3128 |
| `squid.conf`, `allowed-domains.txt` | ConfigMap mounted read-only in the proxy pod |
| `agent` network with `internal: true` | **NetworkPolicy**: the sandbox pod may only reach the proxy (and cluster DNS) |
| `egress` network | NetworkPolicy allowing the proxy pod out on ports 80/443 |
| Named volumes | PersistentVolumeClaims |
| API keys and tokens on volumes | Secrets (still readable by the agent, see [networking.md](networking.md#limits)) |

### Forcing traffic through the proxy

Kubernetes networks are flat by default: every pod can reach the Internet. A NetworkPolicy replaces `internal: true`:

```yaml
# Deny all traffic in the namespace unless allowed below
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
spec:
  podSelector: {}
  policyTypes: [Ingress, Egress]
---
# Sandbox: out only to the proxy and cluster DNS; in only from the ingress controller
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: sandbox
spec:
  podSelector:
    matchLabels: { app: sandbox }
  policyTypes: [Ingress, Egress]
  ingress:
    - from:
        - namespaceSelector:
            matchLabels: { kubernetes.io/metadata.name: ingress-nginx }
      ports:
        - { protocol: TCP, port: 4096 } # opencode web port
  egress:
    - to:
        - podSelector:
            matchLabels: { app: proxy }
      ports:
        - { protocol: TCP, port: 3128 }
    - to:
        - namespaceSelector:
            matchLabels: { kubernetes.io/metadata.name: kube-system }
          podSelector:
            matchLabels: { k8s-app: kube-dns }
      ports:
        - { protocol: UDP, port: 53 }
        - { protocol: TCP, port: 53 }
---
# Proxy: in only from the sandbox; out to the Internet on 80/443, not to internal ranges
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: proxy
spec:
  podSelector:
    matchLabels: { app: proxy }
  policyTypes: [Ingress, Egress]
  ingress:
    - from:
        - podSelector:
            matchLabels: { app: sandbox }
      ports:
        - { protocol: TCP, port: 3128 }
  egress:
    - to:
        - ipBlock:
            cidr: 0.0.0.0/0
            except: [10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, 169.254.0.0/16]
      ports:
        - { protocol: TCP, port: 80 }
        - { protocol: TCP, port: 443 }
    - to:
        - namespaceSelector:
            matchLabels: { kubernetes.io/metadata.name: kube-system }
          podSelector:
            matchLabels: { k8s-app: kube-dns }
      ports:
        - { protocol: UDP, port: 53 }
        - { protocol: TCP, port: 53 }
```

Labels, the ingress controller namespace and the opencode port depend on the deployment; adapt them.

### Points of attention

- **The CNI must enforce NetworkPolicy** (Calico, Cilium…). Some network plugins (Flannel alone) accept the objects and silently ignore them. Test it: from the sandbox pod, `curl --noproxy '*' https://example.com` must fail.
- **DNS**: unlike the Docker `internal` network, the sandbox needs cluster DNS to resolve the proxy Service, and cluster DNS also resolves external names. This reopens a DNS exfiltration channel. To close it, point `HTTP(S)_PROXY` at the Service ClusterIP and remove the DNS rule from the sandbox policy, or restrict what CoreDNS resolves for that namespace.
- **Domain filtering stays in Squid**: NetworkPolicy works on IPs and ports, not domain names. CNI-specific FQDN policies (such as Cilium's `toFQDNs`) could replace the proxy, at the cost of portability.
- **Authentication**: the web UI gives a shell-equivalent access to the sandbox. Never expose it without authentication in front (ingress authentication, oauth2-proxy…), and use one pod per user.
- **Pod hardening**: apply the `restricted` [Pod Security Standard](https://kubernetes.io/docs/concepts/security/pod-security-standards/) to the namespace (non-root, no privilege escalation, all capabilities dropped, default seccomp profile). The node and cluster hardening plays the role of [Docker hardening](docker-hardening.md).

None of the domains linked on this page are needed by the sandbox; only the agents' API and login domains are, as listed above.
