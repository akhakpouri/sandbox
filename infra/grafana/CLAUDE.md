# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## grafana/

No standalone manifests live here — Grafana runs as the bundled subchart of the `kube-prometheus-stack` Helm release (`infra-prometheus`), enabled via `grafana.enabled: true` in `infra/prometheus/helm/infra/values.yaml`. See `docs/project-notes/facts.md` (grafana row) and the `decisions.md` 2026-08-20 entry for why the original "hand-write Grafana separately" plan was dropped in favor of keeping the bundled instance.

- Service: `infra-prometheus-grafana` (ClusterIP, port 80) — reach it via `kubectl port-forward -n infra svc/infra-prometheus-grafana 3000:80`.
- Login: admin credentials are in the auto-generated `infra-prometheus-grafana` Secret (`admin-user`/`admin-password` keys), not overridden by anything in this repo.
- Datasources: `Prometheus` and `Alertmanager` are auto-provisioned by the chart (see the `infra-prometheus-kube-prom-grafana-datasource` ConfigMap) — no manual datasource setup needed.
