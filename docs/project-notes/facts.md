# Facts

Project configuration: ports, namespaces, images, service names. Not a place for actual secret values — those live in each component's `secret.yaml`.

## Namespaces
- `default` — mongodb, mongodb-express, nginx
- `kubernetes-dashboard` — dashboard ingress target (Dashboard itself installed out-of-band, not by this repo)
- `infra` — observability/infra/platform tooling: redis + prometheus (deployed), grafana (in progress), vault + argocd (planned) (see `decisions.md` for why this is separate from `default`)

## Components

| Component | Image / Chart | Port(s) | Service type | Notes |
|---|---|---|---|---|
| mongodb | `mongo` | 27017 | ClusterIP (`mongodb-service`) | root creds via `mongodb-secret` |
| mongodb-express | `mongo-express` | 8081 | LoadBalancer, nodePort 30000 | UI for mongodb, basic auth disabled |
| nginx | `nginx` | container 8080 / svc 80→8080 | ClusterIP (`nginx-service`) | see bugs.md — likely port mismatch |
| dashboard | (ingress only) | 80 | Ingress, host `dashboard.local` | targets existing `kubernetes-dashboard` Service |
| redis | `redis` | 6379, 9121 (exporter) | NodePort (`redis-service`) | `infra` namespace; single-replica Deployment (planned move to StatefulSet later); AOF persistence via `redis-pvc` (`standard` storageClass, RWO); no `requirepass` set yet; `oliver006/redis_exporter` native sidecar (K8s 1.29+ `restartPolicy: Always` init container) + `ServiceMonitor` (`sm-redis`) feed Prometheus — see `infra/redis/CLAUDE.md` |
| prometheus stack | Helm — `kube-prometheus-stack` (prometheus-community), release `infra-prometheus` | 9090 (prometheus), 9093 (alertmanager) | ClusterIP, access via `kubectl port-forward` | `infra` namespace; bundles Alertmanager, node-exporter (DaemonSet), kube-state-metrics, Prometheus Operator (CRDs: `Prometheus`/`Alertmanager`/`ServiceMonitor`/etc.); Grafana subchart disabled (`grafana.enabled: false`); Prometheus has a 1Gi PVC via `prometheusSpec.storageSpec.volumeClaimTemplate`; values override at `infra/prometheus/helm/infra/values.yaml`; see `decisions.md` 2026-08-18 entries |

**Planned, not yet created:**

| Component | Install method | Notes |
|---|---|---|
| grafana | hand-written manifests, `infra` namespace | in progress; datasource wired to `http://infra-prometheus-kube-prom-prometheus.infra.svc.cluster.local:9090` |
| vault | Helm — `hashicorp/vault` | after grafana; zero deps, goes before argocd; see `decisions.md` 2026-08-18 entry |
| argocd | Helm — `argo-helm/argo-cd` | after vault; open question whether it gets pointed at this repo as a GitOps source — see `decisions.md` 2026-08-18 entry |

## Other infra services considered but not yet scaffolded
Covered by the kube-prometheus-stack chart already installed: Alertmanager, kube-state-metrics, node-exporter. redis-exporter is now done too (see redis row above). Still open/unscaffolded: Loki + Promtail/Grafana Agent (logs), Tempo or Jaeger (traces — needed before `otel` collector is useful), redis-commander/RedisInsight (Redis GUI, mongo-express equivalent), metrics-server (`kubectl top`/HPA), cert-manager (TLS), minio (S3-compatible object storage). Confirm ingress-nginx controller is actually installed on the cluster — `dashboard/` assumes one exists but nothing here installs it.

## Cluster assumptions
- Local cluster (host names like `dashboard.local` imply minikube/kind/Docker Desktop + an Ingress controller, not a managed cloud cluster).
- `dashboard.local` must be mapped to the ingress IP in the local hosts file to resolve.
