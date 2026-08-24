# infra/

The `infra` namespace: platform and observability tooling for this local dev suite, kept separate from the app-ish components elsewhere in the repo (`db/`, `dashboard/`). Deployed and `Active` on the cluster today, but note: unlike every real component inside it, the namespace itself isn't tracked as a manifest here (no `infra/namespace.yaml` — it was created out-of-band, despite `docs/project-notes/decisions.md` originally planning for one). `kubectl create namespace infra` if you're rebuilding from scratch.

## What's deployed

| Component | What it is | Install method | Access |
|---|---|---|---|
| [`redis/`](redis/) | Cache/broker, AOF persistence, exporter sidecar | Plain YAML: `kubectl apply -f infra/redis/` | NodePort `30197` (`6379`) |
| [`prometheus/`](prometheus/) | `kube-prometheus-stack` — Prometheus, Alertmanager, node-exporter, kube-state-metrics, the Operator | Helm, release `infra-prometheus` | `kubectl port-forward -n infra svc/infra-prometheus-kube-prom-prometheus 9090:9090` |
| [`grafana/`](grafana/) | Bundled subchart of the same `infra-prometheus` release — no standalone manifests | (rides along with prometheus) | `kubectl port-forward -n infra svc/infra-prometheus-grafana 3000:80` |
| [`vault/`](vault/) | Secrets management, **dev mode** (in-memory storage) | Helm, release `infra-vault` | NodePort `31978` (`8200`) — see the macOS gotcha below |
| [`localstack/`](localstack/) | AWS service emulation (SQS, SNS) | Plain YAML: `kubectl apply -f infra/localstack/` | NodePort `30505` (`4566` edge) |

Each directory has its own `README.md` (quick start) and `CLAUDE.md` (full config/gotchas) — this file is just the map.

## How the pieces connect

- **redis → prometheus**: `infra/redis/service-monitor.yaml` (`sm-redis`) makes the Prometheus Operator scrape the redis exporter sidecar automatically — no manual scrape config.
- **prometheus → grafana**: the `Prometheus` and `Alertmanager` datasources are auto-provisioned by the chart the moment `grafana.enabled: true` is set. Nothing to wire up by hand.
- **vault → localstack**: the first (and so far only) real consumer of a Vault secret in this cluster. `localstack-deployment`'s pod runs two initContainers before the main container starts: `vault-fetch` logs into Vault via Kubernetes auth (using the pod's own `localstack-sa` identity) and reads `secret/localstack`; `k8s-secret-sync` writes that value into a native `localstack-vault-secret` Secret, which the main container consumes via a normal `secretKeyRef`. See `infra/localstack/README.md` for the full diagram.

## Known gotcha: Vault dev mode has no persistence

`infra/vault/helm/infra/values.yaml` runs Vault with `server.dev.enabled: true` — single pod, **in-memory storage**, already unsealed. Convenient for a sandbox, but every restart of `infra-vault-0` wipes everything configured after initial unseal: the `kubernetes` auth method, the `localstack` role/policy binding, and the `secret/localstack` KV entry all reset to nothing (only the root token, `root`, comes back — it's the chart default, not persisted state). When that happens, LocalStack's `vault-fetch` initContainer starts failing with `403 permission denied` and the pod gets stuck.

Fix: `./infra/localstack/load-secret.sh` — idempotently re-enables the kubernetes auth method, re-configures it, rewrites the policy and role, and re-populates `secret/localstack` (token pulled from a local, gitignored `infra/localstack/.env`, never hardcoded). Re-run it any time `infra-vault-0` has restarted and LocalStack is stuck.

## Reaching NodePort services from a Mac

This cluster runs minikube on the `docker` driver. On macOS, the node IP `kubectl get svc` shows you (e.g. `192.168.49.2:31978`) lives only inside Docker Desktop's VM — it's not reachable from the host at all. Don't use it directly. Instead:

```
minikube service <service-name> -n infra
```

Keep that terminal open and use the *second* table's `http://127.0.0.1:<port>` URL it prints — the first table's node-IP URL will look right but won't connect. The port is random per run, so a URL you saved last week is probably stale. Full writeup in [`docs/project-notes/bugs.md`](../docs/project-notes/bugs.md).

## Present but not deployed (scratch/tutorial work)

| Path | Status |
|---|---|
| [`nginx/`](nginx/) | Never applied; has a stock-image port mismatch bug, not worth fixing since nothing depends on it |
| [`volumes/`](volumes/) | Never applied; PV points at an NFS server that doesn't exist on this cluster |

## Planned

- **ArgoCD** — next up, via its official Helm chart (`argo-helm/argo-cd`), same pattern as Vault/Prometheus. Open question (deliberately unresolved): whether it ends up pointed at this repo as a GitOps source.

## Deeper reference

- [`docs/project-notes/facts.md`](../docs/project-notes/facts.md) — exact ports, images, service names for everything above
- [`docs/project-notes/decisions.md`](../docs/project-notes/decisions.md) — why each component is chart-based vs. hand-written, build order, and reasoning
- [`docs/project-notes/bugs.md`](../docs/project-notes/bugs.md) — issues hit and fixed while building this out
