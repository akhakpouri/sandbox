# Bugs

Bug log with root cause and solution once resolved. Newest first.

## Open

### nginx Service/Deployment port mismatch — 2026-08-15
`nginx/deployment.yaml` sets `containerPort: 8080` and `nginx/service.yaml` forwards `targetPort: 8080`, but the stock `nginx` image serves on port `80` by default and nothing in the manifest changes that (no custom `nginx.conf`, no `-p` flag override). As written, `nginx-service` likely can't reach the container.

**Fix options:** either set `containerPort: 80` / `targetPort: 80` to match the stock image, or ship a ConfigMap-mounted `nginx.conf` that has nginx `listen 8080`.

**Status:** unconfirmed — flagged during repo review, not yet verified against a running cluster.
