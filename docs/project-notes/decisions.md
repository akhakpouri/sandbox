# Decisions

Architectural decisions and the reasoning behind them. Newest first.

## Shared dummy credentials across mongodb and mongodb-express — 2026-08-15
`mongodb/secret.yaml` and `mongodb-express/secret.yaml` contain identical base64 values. Treated as intentional for this sandbox (mongo-express authenticates as the mongo root user), not a copy-paste bug — don't "fix" by generating different values without confirming with the user first.

## No Helm/Kustomize — 2026-08-15
Components are managed as plain per-directory YAML applied individually with `kubectl apply -f <dir>/`. Keep new components (redis, grafana, otel, etc.) in this same flat, per-directory style unless the user asks to introduce a templating/packaging layer.

## `infra` namespace for observability/infra tooling — 2026-08-15
New non-app infra components (`redis`, `prometheus`, `grafana`, and future `otel`) deploy into a dedicated `infra` namespace (`infra/namespace.yaml`) instead of `default`. Existing components (`mongodb`, `mongodb-express`, `nginx`, `dashboard`) stay in `default`/`kubernetes-dashboard` — not migrated, to avoid touching a working setup without a concrete reason. Revisit only if there's a real need to unify namespaces.

## Recommended build order: infra namespace → redis → prometheus → grafana — 2026-08-15
1. **`infra/namespace.yaml`** first — everything else depends on the namespace existing.
2. **`redis`** — zero dependencies, stock image works out of the box. Good first deploy to validate the new namespace/networking actually works, the same role `mongodb` played before `mongodb-express`.
3. **`prometheus`** — also standalone (ships a working default config that self-scrapes), but deploy it before Grafana since Grafana is only useful once there's a datasource to point at.
4. **`grafana`** — deploy last; wire it to `http://prometheus-service.infra.svc.cluster.local:9090` as a datasource once Prometheus is confirmed running.

`otel` (collector) comes after this core loop, once there's a trace/log backend (Tempo/Loki) worth exporting to — not scaffolded yet. See `docs/project-notes/facts.md` for the full candidate list (Alertmanager, Loki, Tempo, kube-state-metrics, node-exporter, redis-exporter, metrics-server, etc.) suggested alongside this namespace.

## Per-directory CLAUDE.md files — 2026-08-15
In addition to the root `CLAUDE.md`, each component directory gets its own short `CLAUDE.md` describing just that component. As new products (redis, grafana, otel, ...) are added, give each its own directory + `CLAUDE.md` following the existing pattern rather than growing the root file indefinitely.
