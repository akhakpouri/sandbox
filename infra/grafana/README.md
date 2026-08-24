# Grafana

Not a standalone deployment — Grafana rides along in the `infra-prometheus` Helm release (see [`../prometheus/README.md`](../prometheus/README.md)), enabled via `grafana.enabled: true` in `infra/prometheus/helm/infra/values.yaml`. There's nothing to `kubectl apply` in this directory.

## Quick start

```
kubectl port-forward -n infra svc/infra-prometheus-grafana 3000:80
```

Login: admin credentials are in the auto-generated `infra-prometheus-grafana` Secret (`admin-user`/`admin-password` keys). `Prometheus` and `Alertmanager` datasources are pre-provisioned by the chart — nothing to wire up manually.

See [`CLAUDE.md`](CLAUDE.md), and [`docs/project-notes/decisions.md`](../../docs/project-notes/decisions.md) (2026-08-20 entry) for why this ended up bundled instead of hand-written as originally planned.
