# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## argocd/

ArgoCD — GitOps controller for the `infra` namespace's components — installed via the official `argo-helm/argo-cd` Helm chart, in its **own dedicated `argocd` namespace**, not `infra`. Deliberate deviation from where the 2026-08-18 decisions.md entry originally sketched it (lumped in with `infra`): keeping the GitOps control plane separate from the workloads it manages means either side can be deleted/reinstalled independently. Values override at `infra/argocd/helm/argocd/values.yaml`.

Install:

```
helm repo add argo https://argoproj.github.io/argo-helm
kubectl create namespace argocd
helm install argocd argo/argo-cd -n argocd -f infra/argocd/helm/argocd/values.yaml
```

Release name is `argocd`, not `infra-argocd` — the `infra-` prefix on Vault/Prometheus exists to disambiguate multiple releases sharing the `infra` namespace; ArgoCD has its own namespace, nothing to disambiguate, and `argocd` matches what the chart's own resource names (`argocd-server`, `argocd-repo-server`, ...) and virtually every ArgoCD doc/tutorial assume.

**Values overridden** (everything else left at chart default — checked against `helm show values argo/argo-cd` directly rather than assumed):
- `configs.params."server.insecure": true` — server speaks plain HTTP internally. Paired with `kubectl port-forward`, this skips the self-signed-cert browser warning. Sandbox-only reasoning, consistent with the rest of this repo.
- `dex.enabled: false` — Dex (the bundled OIDC/SSO connector) defaults to `true` in the chart and runs its own pod. Not needed — this sandbox uses only local admin auth. Same "nothing here needs it yet" reasoning that kept Vault's Agent Injector off.
- `notifications.enabled: false` — the notifications controller also defaults to `true`/its own pod. No Slack/webhook targets configured, nothing to notify.

**Deliberately left at default, not written to the file:**
- `server.service.type` — stays `ClusterIP`. Access via `kubectl port-forward -n argocd svc/argocd-server 8080:443` (or plain `80`, since `server.insecure: true`), the same pattern as Prometheus/Grafana rather than Vault/LocalStack's NodePort. Reasoning: this UI gets checked constantly while learning ArgoCD, and NodePort means redoing the `minikube service` tunnel dance (random port, terminal must stay open — see `docs/project-notes/bugs.md`) every time on this macOS/`docker`-driver cluster. Port-forward has none of that friction.
- `redis.enabled` — stays `true`. This is ArgoCD's **own internal Redis** (repo-server caching), a required part of the chart, not optional. Different namespace (`argocd`), different release, no relation to `infra/redis/` — don't confuse the two if `kubectl get pods -A` shows two Redis-looking pods.

**Admin credentials**: not overridden — chart auto-generates `argocd-initial-admin-secret` in the `argocd` namespace (`password` key, username `admin`). Same "not overridden" convention as Vault's root token and Grafana's admin password elsewhere in this repo. Retrieve with:
```
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

**CRDs**: bundled with the chart (`Application`, `AppProject`, `ApplicationSet`), installed on first `helm install`. Same caution as the `kube-prometheus-stack` chart (`infra/prometheus/CLAUDE.md`): not auto-upgraded by `helm upgrade` — re-apply CRDs manually after a chart version bump that changes them.

## App-of-Apps structure

`root-app.yaml` — the single `Application` manifest applied by hand, once:
```
kubectl apply -f infra/argocd/root-app.yaml
```
It points `source.repoURL` at this repo's own GitHub remote (`https://github.com/akhakpouri/sandbox.git`) and `source.path` at `infra/argocd/apps/` — everything in that directory becomes a child `Application` that ArgoCD creates and reconciles on its own from then on. This repo doubles as both the "app repo" and the "GitOps config repo" — deliberate, not a shortcut: `k8s-sandbox` has never held application source code, only infra manifests, so the usual reason to split them (avoiding CI rebuild loops on config-only commits) doesn't apply here. See `docs/project-notes/decisions.md` for the fuller reasoning.

`infra/argocd/apps/` (in progress): one `Application` per component, gated into sync waves via `argocd.argoproj.io/sync-wave` annotations —
- **wave 0**: `redis-app.yaml`, `vault-app.yaml`, `prometheus-app.yaml` — no interdependencies, sync in parallel.
- **wave 1**: `vault-bootstrap-job.yaml` — a `PostSync` hook Job (adapted from `infra/localstack/load-secret.sh`'s logic) that waits for `vault-app` to be Healthy, then re-configures Vault's kubernetes auth method, policy, role, and `secret/localstack` — all of which reset to nothing on every Vault dev-mode restart (`infra/vault/CLAUDE.md`).
- **wave 2**: `localstack-app.yaml` — waits for the bootstrap Job to reach `Complete`, since its `vault-fetch` initContainer needs Vault already configured, not just running.

Not yet designed: how `vault-app`/`prometheus-app` source their *upstream* Helm charts through ArgoCD (likely multi-source `Application`s, so `infra/vault/helm/infra/values.yaml` stays the single source of truth instead of being copy-pasted inline), and where `vault-bootstrap-job.yaml`'s secrets (`LOCALSTACK_AUTH_TOKEN`, Vault's root token) come from non-interactively, since the Job can't read the local gitignored `infra/localstack/.env`.
