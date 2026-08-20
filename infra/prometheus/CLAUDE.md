# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## prometheus/

Prometheus in the `infra` namespace, installed via the official `kube-prometheus-stack` Helm chart (prometheus-community) — not hand-written manifests, per `docs/project-notes/decisions.md` (2026-08-18 entry: mostly RBAC/scrape-config boilerplate, low learning value to hand-write). Values override at `infra/prometheus/helm/infra/values.yaml`.

**Installed** — release `infra-prometheus`:

```
helm install infra-prometheus prometheus-community/kube-prometheus-stack -n infra -f infra/prometheus/helm/infra/values.yaml
```

- Bundles Alertmanager, node-exporter (DaemonSet), kube-state-metrics, and the Prometheus Operator (CRDs: `Prometheus`/`Alertmanager`/`ServiceMonitor`/etc.).
- Prometheus: ClusterIP service `infra-prometheus-kube-prom-prometheus`, port 9090 — `kubectl port-forward -n infra svc/infra-prometheus-kube-prom-prometheus 9090:9090`. Has a 1Gi PVC via `prometheusSpec.storageSpec.volumeClaimTemplate` (`standard` storageClass).
- Alertmanager: ClusterIP service `infra-prometheus-kube-prom-alertmanager`, port 9093.
- `grafana.enabled: true` — the bundled Grafana subchart is also deployed from this same release; see `infra/grafana/CLAUDE.md` and the `decisions.md` 2026-08-20 entry (this reverses an earlier plan to disable the subchart and hand-write Grafana separately).
- redis is scraped via the `sm-redis` ServiceMonitor in `infra/redis/service-monitor.yaml` — no changes needed here for that.
