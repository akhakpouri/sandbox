# Bugs

Bug log with root cause and solution once resolved. Newest first.

## Resolved

### NodePort services unreachable at the node IP on macOS (minikube `docker` driver) — 2026-08-19
`kubectl get svc` for any NodePort service (e.g. `infra-vault`) shows a URL like `http://192.168.49.2:31978`. On this cluster (minikube, `docker` driver, macOS host), that node IP lives only on Docker Desktop's internal network — it's not routable from the Mac host at all. Confirmed: `ping 192.168.49.2` from the host is 100% packet loss and `curl` to it times out, while the same request run inside the minikube container (`docker exec minikube curl ...`) succeeds immediately. Linux hosts don't hit this — the `docker` driver's bridge network sits on the host's own network namespace there; only the macOS (Docker Desktop VM) case is affected.

**Fix:** don't use the node IP. Run `minikube service <name> -n <namespace>`, which opens an SSH-style tunnel and prints a *second* table with a `http://127.0.0.1:<random-port>` URL — that's the one to open in a browser. Two gotchas: (1) the command's first table still prints the unreachable node-IP URL, easy to grab by mistake — use the second table, after "Starting tunnel"; (2) the tunnel only lives as long as that terminal command keeps running (minikube says so explicitly: "the terminal needs to be open to run it") and a fresh run assigns a new random port each time, so old URLs go stale as soon as you close or restart it.

**Status:** resolved — hit and diagnosed against `infra-vault`'s NodePort service; applies to any NodePort service on this cluster, not just Vault.

## Open

### nginx Service/Deployment port mismatch — 2026-08-15
`nginx/deployment.yaml` sets `containerPort: 8080` and `nginx/service.yaml` forwards `targetPort: 8080`, but the stock `nginx` image serves on port `80` by default and nothing in the manifest changes that (no custom `nginx.conf`, no `-p` flag override). As written, `nginx-service` likely can't reach the container.

**Fix options:** either set `containerPort: 80` / `targetPort: 80` to match the stock image, or ship a ConfigMap-mounted `nginx.conf` that has nginx `listen 8080`.

**Status:** unconfirmed — flagged during repo review, not yet verified against a running cluster.
