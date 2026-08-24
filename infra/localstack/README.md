# LocalStack

Local AWS service emulation (currently SQS + SNS) in the `infra` namespace — hand-written manifests, and the first real consumer of a Vault-backed secret in this cluster.

## Quick start

```
kubectl apply -f infra/localstack/
kubectl get pods -n infra -l app=localstack-app
```

Reachable at NodePort `30505` (edge port `4566` — check `kubectl get svc -n infra localstack-service` if it's changed), e.g.:
```
aws --endpoint-url=http://<host>:<nodeport> sqs create-queue --queue-name test-queue --region us-east-1
```
Dummy `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY` are enough — LocalStack doesn't validate real credentials.

## How the auth token gets in

As of LocalStack 2026.03.0, even free/Community-tier usage requires a `LOCALSTACK_AUTH_TOKEN` (a free Hobby-plan token from app.localstack.cloud — see [`docs/project-notes/bugs.md`](../../docs/project-notes/bugs.md)). Rather than a plain `Secret`, that token is delivered from Vault:

1. **`vault-fetch`** initContainer authenticates to Vault via Kubernetes auth, using the pod's own `localstack-sa` identity, and reads `secret/localstack`.
2. **`k8s-secret-sync`** initContainer writes that value into a native `localstack-vault-secret` Secret.
3. The main container consumes it normally via `secretKeyRef` — no different from any other secret in this repo.

This requires the Vault-side setup to already exist: Kubernetes auth method enabled, the `localstack-read` policy (`policy.hcl`), and `secret/localstack` populated with a real token — otherwise `vault-fetch` fails and the pod sits at `Init:0/2`. See [`CLAUDE.md`](CLAUDE.md) for the exact `vault` commands, and [`docs/project-notes/decisions.md`](../../docs/project-notes/decisions.md) (2026-08-20 entry) for why a manual initContainer chain was chosen over the Vault Agent Injector.
