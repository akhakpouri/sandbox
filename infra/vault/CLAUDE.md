# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## vault/

Vault in the `infra` namespace, installed via the official `hashicorp/vault` Helm chart — not hand-written manifests, per `docs/project-notes/decisions.md`. Values override at `infra/vault/helm/infra/values.yaml`:

- `server.dev.enabled: true` — dev mode: single pod, in-memory storage, already unsealed, no HA/raft. Sandbox-only, matches the reasoning that kept this chart-based instead of hand-rolled (see decisions.md 2026-08-18 entry).
- `server.service.type: NodePort` — reachable without `kubectl port-forward`; check the assigned port with `kubectl get svc -n infra`.
- `injector.enabled: false` — the chart's Vault Agent Injector (mutating webhook for sidecar injection) is disabled; nothing in this repo needs it yet.

**Installed** — release `infra-vault`, deployed 2026-08-19:

```
helm install infra-vault hashicorp/vault -n infra -f infra/vault/helm/infra/values.yaml
```

Single pod `infra-vault-0`, confirmed via `vault status`: `Sealed false`, `Storage Type inmem`, `HA Enabled false` — dev mode as expected, no manual unseal needed. `server.dev.devRootToken` was not set, so the root token is the chart's default (`root`).

To exec into the pod directly: `kubectl exec -it -n infra infra-vault-0 -- sh` — the image has no `bash`, only `sh`. `vault` CLI is already on `PATH` inside the container, so this is a way to run `vault` commands without installing the CLI locally.

NodePort assigned by the cluster: **31978** (API/UI on container port 8200 — check `kubectl get svc -n infra infra-vault` if it changes across reinstalls). **The node IP is not directly reachable from the Mac host** (minikube `docker` driver on macOS — see `docs/project-notes/bugs.md`). To reach the UI: run `minikube service infra-vault -n infra`, keep that terminal open, and use the *second* table's `127.0.0.1:<port>` URL it prints (a fresh random port every run — ignore the first table's `192.168.49.2:...` URL). Login with the root token above.
