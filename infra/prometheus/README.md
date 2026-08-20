# Prometheus + Grafana

The observability stack for this cluster — installed via the official `kube-prometheus-stack` Helm chart (release `infra-prometheus`), which bundles Prometheus, Alertmanager, node-exporter, kube-state-metrics, and — via `grafana.enabled: true` — Grafana itself. See [`../grafana/README.md`](../grafana/README.md) for Grafana-specific access.

## Quick start

```
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install infra-prometheus prometheus-community/kube-prometheus-stack -n infra -f infra/prometheus/helm/infra/values.yaml
```

- Prometheus UI: `kubectl port-forward -n infra svc/infra-prometheus-kube-prom-prometheus 9090:9090`
- Alertmanager: `kubectl port-forward -n infra svc/infra-prometheus-kube-prom-alertmanager 9093:9093`

See [`CLAUDE.md`](CLAUDE.md) for the full component breakdown (Operator CRDs, node-exporter, kube-state-metrics) and PVC details.
