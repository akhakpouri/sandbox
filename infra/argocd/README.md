# ArgoCD

GitOps controller for everything in `infra/` — installed via the official `argo-helm/argo-cd` Helm chart, in its own `argocd` namespace (separate from what it manages).

## Quick start

```
helm repo add argo https://argoproj.github.io/argo-helm
kubectl create namespace argocd
helm install argocd argo/argo-cd -n argocd -f infra/argocd/helm/argocd/values.yaml
```

UI: `kubectl port-forward -n argocd svc/argocd-server 8080:443`, then open `https://localhost:8080` (or `http://` — `server.insecure: true` is set, so plain HTTP works too).

Login `admin` / whatever's in the auto-generated secret:
```
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

## The one manual command, going forward

```
kubectl apply -f infra/argocd/root-app.yaml
```

That's the App-of-Apps root — from then on, ArgoCD watches `infra/argocd/apps/` in this repo and creates/syncs everything in `infra/` (redis, vault, prometheus, localstack) on its own. No more manual `kubectl apply -f infra/<component>/` or `helm install` for those.

See [`CLAUDE.md`](CLAUDE.md) for the full values breakdown, the App-of-Apps sync-wave ordering, and what's still being designed (Helm chart sourcing, secret bootstrapping).
