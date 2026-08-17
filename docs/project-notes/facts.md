# Facts

Project configuration: ports, namespaces, images, service names. Not a place for actual secret values — those live in each component's `secret.yaml`.

## Namespaces
- `default` — mongodb, mongodb-express, nginx
- `kubernetes-dashboard` — dashboard ingress target (Dashboard itself installed out-of-band, not by this repo)
- `infra` — observability/infra tooling: redis, prometheus, grafana, and future additions (see `decisions.md` for why this is separate from `default`)

## Components

| Component | Image | Port(s) | Service type | Notes |
|---|---|---|---|---|
| mongodb | `mongo` | 27017 | ClusterIP (`mongodb-service`) | root creds via `mongodb-secret` |
| mongodb-express | `mongo-express` | 8081 | LoadBalancer, nodePort 30000 | UI for mongodb, basic auth disabled |
| nginx | `nginx` | container 8080 / svc 80→8080 | ClusterIP (`nginx-service`) | see bugs.md — likely port mismatch |
| dashboard | (ingress only) | 80 | Ingress, host `dashboard.local` | targets existing `kubernetes-dashboard` Service |

**Planned, not yet created** (`infra` namespace) — directories exist with a `CLAUDE.md` each; manifests are being hand-written by the user, not scaffolded:

| Component | Image (planned) | Notes |
|---|---|---|
| redis | `redis` | first in build order — zero deps, validates `infra` namespace/networking |
| prometheus | `prom/prometheus` | needed as Grafana's datasource before Grafana is useful |
| grafana | `grafana/grafana` | deploy last; wire to prometheus once it's running |

## Other infra services considered but not yet scaffolded
Suggested when `infra` namespace was introduced, for later: Alertmanager (Prometheus alert routing), Loki + Promtail/Grafana Agent (logs), Tempo or Jaeger (traces — needed before `otel` collector is useful), kube-state-metrics + node-exporter (cluster metrics sources), redis-exporter, redis-commander/RedisInsight (Redis GUI, mongo-express equivalent), metrics-server (`kubectl top`/HPA), cert-manager (TLS), minio (S3-compatible object storage). Confirm ingress-nginx controller is actually installed on the cluster — `dashboard/` assumes one exists but nothing here installs it.

## Cluster assumptions
- Local cluster (host names like `dashboard.local` imply minikube/kind/Docker Desktop + an Ingress controller, not a managed cloud cluster).
- `dashboard.local` must be mapped to the ingress IP in the local hosts file to resolve.
