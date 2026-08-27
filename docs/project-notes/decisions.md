# Decisions

Architectural decisions and the reasoning behind them. Newest first.

## PostgreSQL via CloudNativePG, backed by Rook/Ceph for distributed storage — planned, 2026-08-25
Next additions after the ArgoCD migration (below) is finished: **PostgreSQL**, run via the **CloudNativePG** (CNPG) operator, with its `Cluster` CRD-managed instances backed by **Rook**-provisioned **Ceph** storage rather than a cloud storage class. Both via their official Helm charts (`cnpg/cloudnative-pg`, `rook-release/rook-ceph` + `rook-ceph-cluster`) — same "operate real platform tooling via its official chart" reasoning already applied to Vault/Prometheus/ArgoCD, not hand-rolled manifests.

**Hard constraint driving the storage choice:** this cluster is on-prem/bare-metal (minikube) — no cloud provider integration, so anything assuming cloud-managed block storage (EBS, GCE PD, Azure Disk) is off the table. Rook/Ceph is the standard on-prem answer: Rook is the operator, Ceph is the actual distributed storage system underneath, and Rook exposes `StorageClass`es (RBD for block, CephFS for shared filesystem, RGW for S3-compatible object) that PVCs can then request — analogous in spirit to how `kube-prometheus-stack`'s Operator manages `Prometheus`/`Alertmanager` CRDs, just for storage instead of monitoring.

CloudNativePG itself: the current de facto standard Postgres-on-Kubernetes operator (CNCF project), handles primary/replica orchestration, automated failover, and backups declaratively via its `Cluster` CRD — the operator-plus-CRD shape this repo already has direct experience with from the Prometheus Operator.

**Open questions, deliberately unresolved until this is actually started:**
- **The existing out-of-band `postgres-app` StatefulSet** (`database` namespace, documented in the root `CLAUDE.md` and `facts.md` as untracked, deployed outside this repo) — this plan needs to explicitly decide its relationship to that: replace it, migrate its data into the new CNPG-managed cluster, or leave it alone as something unrelated. Not assumed either way.
- **Build order between the two**: does Rook/Ceph need to land *before* CloudNativePG so Postgres's PVCs can use a Ceph-backed `StorageClass` from day one, or are they independent (Postgres first on the existing `standard` storageClass, Ceph added later as a storage upgrade)? Undecided.
- **Namespace**: `infra` (matching the rest of platform tooling) vs. a dedicated `database`/`storage` namespace, possibly reconciling with the existing untracked `database` namespace above. Undecided.
- **Single-node topology limits Ceph's actual value proposition.** This cluster is minikube, single-node. Ceph's whole point is distributed replication across failure domains — multiple nodes, multiple disks. It can technically run degraded/single-replica on one node for learning purposes, but can't deliver what it's actually for until minikube grows multi-node (`minikube start --nodes=N` supports this) or this moves to a real multi-node cluster. Worth deciding upfront whether this is a learning-only exercise on a single node, or a prerequisite to multi-node first.
- **Resource cost**: Ceph's mons/mgrs/OSDs have real CPU/memory/disk footprint, more than anything deployed so far — worth sizing against what's actually available on this dev machine before committing.
- **GitOps ownership**: whether these get folded into the ArgoCD App-of-Apps migration (below) once that's fully done, or deployed manually first — natural to decide once ArgoCD is handling everything currently in `infra/`.

## ArgoCD App-of-Apps migration — in progress, status as of 2026-08-24
Resolves the open question left at the end of the 2026-08-18 "ArgoCD and Vault added to the `infra` plan" entry below (whether ArgoCD ends up pointed at this repo as a GitOps source): yes. Shape is App-of-Apps — a single `root-app` Application (`infra/argocd/root-app.yaml`, applied once by hand) watches `infra/argocd/apps/` in this same repo and creates/manages one child Application per component from there. This repo doubles as both the "app repo" and the GitOps config repo — deliberate, not a shortcut: `k8s-sandbox` has never held application source code, only infra manifests, so the usual reason to keep them in separate repos (avoiding CI-rebuild loops on config-only commits) doesn't apply here. ArgoCD itself runs in its own dedicated `argocd` namespace, not `infra` — keeps the GitOps control plane separable from the workloads it manages. Full values breakdown and reasoning: `infra/argocd/CLAUDE.md`.

Sync-wave plan: wave 0 = `redis-app`, `vault-app`, `prometheus-app` (no interdependencies); wave 1 = `vault-bootstrap` (a `PostSync` hook Job re-running `infra/localstack/load-secret.sh`'s logic, since Vault's dev-mode config resets on every restart — see `infra/vault/CLAUDE.md`); wave 2 = `localstack-app` (needs Vault already configured, not just running).

**Status, component by component:**
- **root-app** — applied, `Synced`/`Healthy`.
- **redis-app** — `Synced`/`Healthy`. Full loop proven end-to-end: edited `infra/redis/deployment.yaml`'s resource limits, merged to `main`, ArgoCD picked it up and rolled a new pod with zero `kubectl`/`helm` commands run by hand.
- **vault-app** — `Synced`/`Healthy`. First real test of a multi-source Application (upstream `hashicorp/vault` chart + this repo as a `ref: values` source for `infra/vault/helm/infra/values.yaml`) adopting a pre-existing, manually-`helm install`'d release (`infra-vault`). Went clean — `infra-vault-0` was never restarted, and Vault's in-memory kubernetes-auth config from `load-secret.sh` survived untouched.
- **prometheus-app** — written, same multi-source pattern as vault, adopting `infra-prometheus`. Hit a real issue on first sync: six CRDs failed with a Kubernetes annotation-size limit. See `bugs.md` 2026-08-24 entry for the full root cause — fix (`ServerSideApply=true`) is written into the file and committed locally on `feature/argo-children`, **not yet pushed/merged/verified**.
- **Not started yet**: `vault-bootstrap-job.yaml` and `localstack-app.yaml` (waves 1 and 2). Also still undesigned: where the bootstrap Job's secrets (`LOCALSTACK_AUTH_TOKEN`, Vault's root token) come from non-interactively once it runs in-cluster — it can't read the local, gitignored `infra/localstack/.env` the way the manual script does.

Working on branch `feature/argo-children`, same commit → push → PR-merge-to-`main` workflow as the rest of this repo. Worth remembering going forward: `root-app`'s `targetRevision: HEAD` only ever reflects what's actually on `origin/main` — local edits, and even pushes to a feature branch, are invisible to ArgoCD until merged. Hit this directly earlier in the session (root-app stuck on a stale `ComparisonError` for longer than expected, twice, because changes were pushed to `feature/argo-children` but not yet merged).

## LocalStack's Vault secret delivered via a manual initContainer chain, not the Agent Injector — 2026-08-20
LocalStack (`infra/localstack/`) needs a `LOCALSTACK_AUTH_TOKEN` at startup (see `bugs.md`), and it was deployed specifically as a concrete example of a real workload consuming a Vault secret — everything with Vault before this was CLI-only exploration (`kv put`/`get`, `userpass` policies), nothing in the cluster actually consumed one.

Two real options were weighed: re-enable Vault's Agent Injector (`injector.enabled: true`, currently `false` since the 2026-08-18 Vault decision below), and use pod annotations for auto-injection; or configure Vault's Kubernetes auth method manually and write the fetch logic into a plain initContainer. Chose the manual route. Reasoning: LocalStack only accepts the token as a literal environment variable (no file-based `_FILE` convention) — so *either* approach still needs to bridge "file Vault wrote" → "env var the main container sees," since Vault fundamentally only ever produces files, whether rendered by a hand-written initContainer or the injector's auto-added one. The Injector doesn't remove that bridging step; it only replaces "hand-write the vault-login script" with "3 pod annotations," at the cost of re-enabling a previously-disabled, cluster-wide mutating webhook + controller Deployment to solve a problem that (so far) only exists for one pod. The Injector's real advantage — continuous secret rotation via its sidecar — doesn't apply here since the Hobby-plan auth token is static, not a Vault-issued lease.

Concrete shape implemented: a dedicated `localstack-sa` ServiceAccount, bound via `vault write auth/kubernetes/role/localstack` to a `localstack-read` policy (`secret/data/localstack`, read-only); a `vault-fetch` initContainer (`hashicorp/vault` image) logs in via the pod's own projected SA token and writes the secret value to a shared `emptyDir`; a `k8s-secret-sync` initContainer (`bitnami/kubectl` image) reads that file and `kubectl apply`s it as a native `localstack-vault-secret` Secret, which the main container consumes via a normal `secretKeyRef` — no entrypoint overrides, no changes to the off-the-shelf LocalStack image. Needed a `Role`/`RoleBinding` scoping `localstack-sa` to create/update just that one Secret name, and a one-time `system:auth-delegator` ClusterRoleBinding for Vault's own ServiceAccount so it can call the K8s TokenReview API. See `bugs.md` for the RBAC gotcha hit while wiring this up (`resourceNames` silently blocks `create`, doesn't leave it unrestricted).

`injector.enabled` stays `false` for now — this decision doesn't reopen that one, just documents why it wasn't the answer for this specific case. A future component with an actual need for live secret rotation could still be a legitimate reason to revisit it.

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
