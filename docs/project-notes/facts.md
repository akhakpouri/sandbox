# Facts

Project configuration: ports, namespaces, images, service names. Not a place for actual secret values — those live in each component's `secret.yaml`.

## Namespaces
- `default` — mongodb, mongodb-express, nginx
- `kubernetes-dashboard` — dashboard ingress target (Dashboard itself installed out-of-band, not by this repo)
- `infra` — observability/infra tooling: redis (deployed), prometheus + grafana (planned), and future additions (see `decisions.md` for why this is separate from `default`)

## Components

| Component | Image | Port(s) | Service type | Notes |
|---|---|---|---|---|
| mongodb | `mongo` | 27017 | ClusterIP (`mongodb-service`) | root creds via `mongodb-secret` |
| mongodb-express | `mongo-express` | 8081 | LoadBalancer, nodePort 30000 | UI for mongodb, basic auth disabled |
| nginx | `nginx` | container 8080 / svc 80→8080 | ClusterIP (`nginx-service`) | see bugs.md — likely port mismatch |
| dashboard | (ingress only) | 80 | Ingress, host `dashboard.local` | targets existing `kubernetes-dashboard` Service |
| redis | `redis` | 6379 | NodePort (`redis-service`) | `infra` namespace; single-replica Deployment (planned move to StatefulSet later); AOF persistence via `redis-pvc` (`standard` storageClass, RWO); no `requirepass` set yet — see `infra/redis/CLAUDE.md` |

**Planned, not yet created:**

| Component | Install method | Notes |
|---|---|---|
| prometheus | Helm — `kube-prometheus-stack` (prometheus-community) | bundles Alertmanager, node-exporter, kube-state-metrics; Grafana subchart disabled (`grafana.enabled: false`); see `decisions.md` 2026-08-18 entry |
| grafana | hand-written manifests, `infra` namespace | deploy after prometheus; datasource wired to `http://prometheus-service.infra.svc.cluster.local:9090` |

## Other infra services considered but not yet scaffolded
Now covered by the kube-prometheus-stack chart once installed (see above): Alertmanager, kube-state-metrics, node-exporter. Still open/unscaffolded: Loki + Promtail/Grafana Agent (logs), Tempo or Jaeger (traces — needed before `otel` collector is useful), redis-exporter, redis-commander/RedisInsight (Redis GUI, mongo-express equivalent), metrics-server (`kubectl top`/HPA), cert-manager (TLS), minio (S3-compatible object storage). Confirm ingress-nginx controller is actually installed on the cluster — `dashboard/` assumes one exists but nothing here installs it.

## Cluster assumptions
- Local cluster (host names like `dashboard.local` imply minikube/kind/Docker Desktop + an Ingress controller, not a managed cloud cluster).
- `dashboard.local` must be mapped to the ingress IP in the local hosts file to resolve.
