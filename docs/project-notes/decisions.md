# Decisions

Architectural decisions and the reasoning behind them. Newest first.

## Bundled Grafana kept instead of hand-written — 2026-08-20
Supersedes the "Grafana stays hand-written" half of the 2026-08-18 Prometheus decision below. At some point `grafana.enabled` in `infra/prometheus/helm/infra/values.yaml` was flipped from `false` to `true` outside of any recorded decision — the bundled Grafana subchart turned out to already be running in the `infra` namespace (pod `infra-prometheus-grafana-*`, 46+ hours old when this was noticed on 2026-08-20), while `facts.md` and `infra/grafana/CLAUDE.md` still said "not yet created."

Rather than reverting to match the stale docs, decided to keep the bundled instance and update the docs to match reality instead:
- The chart auto-provisions both a `Prometheus` and an `Alertmanager` datasource (confirmed via the `infra-prometheus-kube-prom-grafana-datasource` ConfigMap) — no manual datasource wiring needed, so the "genuinely new exercise" reasoning from 2026-08-18 no longer applies.
- No standalone `infra/grafana/` manifests will be written — that plan is dropped.
- Admin credentials come from the chart's auto-generated `infra-prometheus-grafana` Secret (`admin-user`/`admin-password` keys), not overridden.

Net effect: Grafana moves from "hand-written, goal-2-style learning exercise" to "chart-managed, same as Prometheus." Doesn't affect the Vault/ArgoCD entry below — that reasoning was about Vault and ArgoCD specifically, not Grafana.

## ArgoCD and Vault added to the `infra` plan, both via Helm chart — 2026-08-18
Extends the build order: after Grafana (in progress) is finished, add **Vault**, then **ArgoCD**, both to `infra`, both installed via their official Helm charts (`hashicorp/vault`, `argo-helm/argo-cd`) — not hand-written manifests.

Order: Vault before ArgoCD. Vault has zero dependency on anything else in the cluster — same "zero deps, good next standalone deploy" reasoning that put redis first originally. ArgoCD is more useful once there are a few real components already deployed for it to manage; less useful as the very next thing added.

Chart-vs-hand-written, and why this isn't the same call as Grafana: hand-writing Vault in dev mode (single Deployment, no unseal/storage backend complexity) was floated first, using the same "low boilerplate → hand-write it" reasoning that kept Grafana hand-rolled. Explicitly overridden by the user: this project has two coexisting learning goals, not one — (1) learn core K8s primitives by hand-writing manifests (redis, Grafana), and (2) learn to operate real platform-engineering tooling *efficiently*, via its official Helm chart plus values overrides, the way it's actually run on a real platform team. ArgoCD and Vault fall under goal 2 — install via chart, configure via values as needed, don't rebuild the stack by hand first.

Open question, deliberately unresolved for now: whether ArgoCD ends up pointed at this repo as a GitOps source — a real shift from "hand-run `kubectl apply` yourself" to "commit and let the controller reconcile." Revisit once ArgoCD is actually being installed, not before.

## Prometheus via kube-prometheus-stack Helm chart; Grafana stays hand-written — 2026-08-18
Scoped reversal of "No Helm/Kustomize" below, for Prometheus only. Hand-writing bare Prometheus is mostly RBAC for Kubernetes service discovery and a scrape-config ConfigMap — boilerplate that's nearly identical across every cluster, low learning value per line. [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack) is the de facto standard way this stack is actually deployed in production, so operating the chart is itself a directly useful skill to build. It installs via the Prometheus Operator (a controller reconciling `Prometheus`/`Alertmanager`/`ServiceMonitor`/`PodMonitor`/`PrometheusRule` CRDs), and bundles Alertmanager, node-exporter (DaemonSet), and kube-state-metrics — all previously listed as "considered but not scaffolded" in `facts.md`.

Grafana stays hand-written (plain `Deployment`, no chart) — wiring it to Prometheus's in-cluster Service DNS as a datasource is a genuinely new exercise, not boilerplate (same "component B talks to component A" shape as mongo-express→mongodb). Bundled Grafana is disabled via a `grafana.enabled: false` values override rather than accepted from the chart.

Working notes for whoever (future self) installs this: read `helm template` output before `helm install` — treat the chart as inspectable, not a black box, same instinct as `kubectl apply --dry-run=client` elsewhere in this repo. This chart's CRDs install only on first `helm install` and are never auto-upgraded or deleted by Helm — re-apply `crds/` manually after a chart version bump that changes them.

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
