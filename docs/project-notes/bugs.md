# Bugs

Bug log with root cause and solution once resolved. Newest first.

## Resolved

### `VAULT_TOKEN` env var silently overrides `vault login`, masking policy restrictions — 2026-08-20
Set up a `userpass` user (`alice`) scoped to a narrow read-only policy, logged in as her with `vault login -method=userpass ...`, and she could still read/write secrets the policy should have blocked. `vault login` reported success and showed the correct scoped-down `token_policies` in its own output — looked like it worked.

Root cause: a `VAULT_TOKEN` environment variable was set in the shell (to the root token, from earlier root-token experimentation) before any of this. The Vault CLI checks `VAULT_TOKEN` *before* the token helper file on every request, and `vault login` warns about this explicitly ("WARNING! The VAULT_TOKEN environment variable is set! The value of this variable will take precedence...") — easy to miss since the login output right below the warning still looks like a normal success message with the *new* user's token/policies. Every subsequent command was actually running as root, not as the logged-in user, regardless of who `vault login` said was authenticated.

**Fix:** `unset VAULT_TOKEN` before relying on `vault login` to switch identities. Verify with `vault token lookup` (shows the policies on whatever token is *actually* active), not just the output of `vault login` itself.

**Status:** resolved — general Vault CLI gotcha, not specific to this cluster; applies to any local shell that has ever `export`ed `VAULT_TOKEN`.

### NodePort services unreachable at the node IP on macOS (minikube `docker` driver) — 2026-08-19
`kubectl get svc` for any NodePort service (e.g. `infra-vault`) shows a URL like `http://192.168.49.2:31978`. On this cluster (minikube, `docker` driver, macOS host), that node IP lives only on Docker Desktop's internal network — it's not routable from the Mac host at all. Confirmed: `ping 192.168.49.2` from the host is 100% packet loss and `curl` to it times out, while the same request run inside the minikube container (`docker exec minikube curl ...`) succeeds immediately. Linux hosts don't hit this — the `docker` driver's bridge network sits on the host's own network namespace there; only the macOS (Docker Desktop VM) case is affected.

**Fix:** don't use the node IP. Run `minikube service <name> -n <namespace>`, which opens an SSH-style tunnel and prints a *second* table with a `http://127.0.0.1:<random-port>` URL — that's the one to open in a browser. Two gotchas: (1) the command's first table still prints the unreachable node-IP URL, easy to grab by mistake — use the second table, after "Starting tunnel"; (2) the tunnel only lives as long as that terminal command keeps running (minikube says so explicitly: "the terminal needs to be open to run it") and a fresh run assigns a new random port each time, so old URLs go stale as soon as you close or restart it.

**Status:** resolved — hit and diagnosed against `infra-vault`'s NodePort service; applies to any NodePort service on this cluster, not just Vault.

## Open

### nginx Service/Deployment port mismatch — 2026-08-15
`nginx/deployment.yaml` sets `containerPort: 8080` and `nginx/service.yaml` forwards `targetPort: 8080`, but the stock `nginx` image serves on port `80` by default and nothing in the manifest changes that (no custom `nginx.conf`, no `-p` flag override). As written, `nginx-service` likely can't reach the container.

**Fix options:** either set `containerPort: 80` / `targetPort: 80` to match the stock image, or ship a ConfigMap-mounted `nginx.conf` that has nginx `listen 8080`.

**Status:** unconfirmed — flagged during repo review, not yet verified against a running cluster.
