# Facts

Project configuration: ports, namespaces, images, service names. Not a place for actual secret values — those live in each component's `secret.yaml`.

## Namespaces
- `default` — mongodb (`db/mongodb/`), mongodb-express (`dashboard/mongodb-express/`). Manifests exist but nothing is currently applied — `kubectl get all -n default` is empty besides the built-in `kubernetes` service.
- `kubernetes-dashboard` — dashboard ingress target (Dashboard itself installed out-of-band, not by this repo)
- `infra` — observability/infra/platform tooling: redis + prometheus + vault + grafana + localstack (all deployed), argocd (planned) (see `decisions.md` for why this is separate from `default`)
- `database` — **not managed by this repo.** A `postgres-app` StatefulSet + `postgres-service` run here, deployed out-of-band with no matching manifest anywhere in git. Discovered 2026-08-20 during a docs-accuracy pass. Documented here so it isn't mistaken for orphaned state; treat as read-only/hands-off unless the user says otherwise.

## Components

| Component | Image / Chart | Port(s) | Service type | Notes |
|---|---|---|---|---|
| mongodb | `mongo` | 27017 | ClusterIP (`mongodb-service`) | at `db/mongodb/`; root creds via `mongodb-secret`; not currently applied |
| mongodb-express | `mongo-express` | 8081 | LoadBalancer, nodePort 30000 | at `dashboard/mongodb-express/`; UI for mongodb, basic auth disabled; not currently applied |
| dashboard | (ingress only) | 80 | Ingress, host `dashboard.local` | targets existing `kubernetes-dashboard` Service |
| redis | `redis` | 6379, 9121 (exporter) | NodePort (`redis-service`) | `infra` namespace; single-replica Deployment (planned move to StatefulSet later); AOF persistence via `redis-pvc` (`standard` storageClass, RWO); no `requirepass` set yet; `oliver006/redis_exporter` native sidecar (K8s 1.29+ `restartPolicy: Always` init container) + `ServiceMonitor` (`sm-redis`) feed Prometheus — see `infra/redis/CLAUDE.md` |
| prometheus stack | Helm — `kube-prometheus-stack` (prometheus-community), release `infra-prometheus` | 9090 (prometheus), 9093 (alertmanager) | ClusterIP, access via `kubectl port-forward` | `infra` namespace; bundles Alertmanager, node-exporter (DaemonSet), kube-state-metrics, Prometheus Operator (CRDs: `Prometheus`/`Alertmanager`/`ServiceMonitor`/etc.); Grafana subchart enabled (`grafana.enabled: true`); Prometheus has a 1Gi PVC via `prometheusSpec.storageSpec.volumeClaimTemplate`; values override at `infra/prometheus/helm/infra/values.yaml`; see `decisions.md` 2026-08-18/2026-08-20 entries |
| vault | Helm — `hashicorp/vault`, release `infra-vault` | 8200 (API/UI), 8201 (cluster) | NodePort (`infra-vault`, NodePort 31978 for 8200) | `infra` namespace; dev mode (`server.dev.enabled: true`) — single pod, in-memory storage, already unsealed, no HA; Agent Injector disabled (`injector.enabled: false`); root token is the chart default (`root`), not overridden; values override at `infra/vault/helm/infra/values.yaml`; Kubernetes auth method enabled (see localstack row) — see `decisions.md` 2026-08-18 entry |
| grafana | Helm — bundled `grafana` subchart of `kube-prometheus-stack`, release `infra-prometheus` | 80 | ClusterIP (`infra-prometheus-grafana`), access via `kubectl port-forward -n infra svc/infra-prometheus-grafana 3000:80` | `infra` namespace; enabled via `grafana.enabled: true` in `infra/prometheus/helm/infra/values.yaml`; no standalone manifests, no separate release; admin creds in auto-generated `infra-prometheus-grafana` Secret (`admin-user`/`admin-password`), not overridden; `Prometheus` + `Alertmanager` datasources auto-provisioned via the `infra-prometheus-kube-prom-grafana-datasource` ConfigMap; see `decisions.md` 2026-08-20 entry |
| localstack | `localstack/localstack` | 4566 (edge), 4510 | NodePort (`localstack-service`) | `infra` namespace; hand-written manifests; `SERVICES=sqs,sns` via `localstack-cm` ConfigMap; `LOCALSTACK_AUTH_TOKEN` delivered from Vault (`secret/localstack`) via a two-step initContainer chain (`vault-fetch` + `k8s-secret-sync`) into a native `localstack-vault-secret` Secret — first real consumer of a Vault secret in this cluster; dedicated `localstack-sa` ServiceAccount bound to Vault's `localstack` Kubernetes-auth role; see `infra/localstack/CLAUDE.md` and `decisions.md` 2026-08-20 entry |

**Planned, not yet created:**

| Component | Install method | Notes |
|---|---|---|
| argocd | Helm — `argo-helm/argo-cd` | zero deps besides vault (done); open question whether it gets pointed at this repo as a GitOps source — see `decisions.md` 2026-08-18 entry |

**Present but unused (`infra/` scratch/tutorial work, not deployed):**

| Path | What it is | Why it's not real |
|---|---|---|
| `infra/nginx/` | Two-replica stock `nginx` Deployment + Service | Never applied; also has the same `containerPort`/stock-image port mismatch as the top-level nginx bug (see `bugs.md`) |
| `infra/volumes/infra-volume.yaml` | A PersistentVolume backed by an NFS server (`172.17.0.2:/tmp`) that doesn't exist on this cluster | Never applied; no PVC in this repo references its `storageClassName: infra` — every real PVC (`redis-pvc`, prometheus's) uses `standard` instead |

## Other infra services considered but not yet scaffolded
Covered by the kube-prometheus-stack chart already installed: Alertmanager, kube-state-metrics, node-exporter. redis-exporter is now done too (see redis row above). Still open/unscaffolded: Loki + Promtail/Grafana Agent (logs), Tempo or Jaeger (traces — needed before `otel` collector is useful), redis-commander/RedisInsight (Redis GUI, mongo-express equivalent), metrics-server (`kubectl top`/HPA), cert-manager (TLS), minio (S3-compatible object storage — largely covered by LocalStack now). Confirm ingress-nginx controller is actually installed on the cluster — `dashboard/` assumes one exists but nothing here installs it.

## Cluster assumptions
- Local cluster (host names like `dashboard.local` imply minikube/kind/Docker Desktop + an Ingress controller, not a managed cloud cluster).
- `dashboard.local` must be mapped to the ingress IP in the local hosts file to resolve.
