# Issues

Work log with ticket references (if any tracker is used) and status. Newest first.

## 2026-08-15 — infra namespace YAML reverted at user's request
User wants to hand-write the `infra`/`redis`/`prometheus`/`grafana` manifests themselves. Deleted the 7 scaffolded YAML files (`infra/namespace.yaml`, `redis/deployment.yaml`, `redis/service.yaml`, `prometheus/deployment.yaml`, `prometheus/service.yaml`, `grafana/deployment.yaml`, `grafana/service.yaml`) and reworded the corresponding `CLAUDE.md` files and `facts.md` to say "planned, not yet created" instead of describing manifests that no longer exist. Kept the namespace decision and recommended build order in `decisions.md` (namespace → redis → prometheus → grafana) since that was explicitly requested as documentation, not implementation.

## 2026-08-15 — infra namespace scaffolded (reverted, see entry above)
Added `infra/namespace.yaml` plus minimal `redis/`, `prometheus/`, `grafana/` scaffolds (Deployment + Service, stock images, no persistence/config yet) and matching `CLAUDE.md` files. Recorded the namespace decision and recommended build order (namespace → redis → prometheus → grafana) in `decisions.md`, and the fuller candidate list (Alertmanager, Loki, Tempo, exporters, etc.) in `facts.md`. Not yet applied to a cluster — Grafana still needs the Prometheus datasource wired up manually.

## 2026-08-15 — Repo bootstrap
Set up root + per-component `CLAUDE.md` files and this `docs/project-notes/` tracking system. Reviewed all existing manifests (`mongodb`, `mongodb-express`, `nginx`, `dashboard`); found the nginx port mismatch (see `bugs.md`) and documented the mongodb/mongodb-express credential-sharing decision (see `decisions.md`). No fixes applied yet — pending user confirmation.
