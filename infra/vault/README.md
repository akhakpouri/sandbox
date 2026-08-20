# Vault

HashiCorp Vault in **dev mode** (single pod, in-memory storage, auto-unsealed) — the secrets-management layer of this suite, installed via the official `hashicorp/vault` Helm chart (release `infra-vault`).

## Quick start

```
helm repo add hashicorp https://helm.releases.hashicorp.com
helm install infra-vault hashicorp/vault -n infra -f infra/vault/helm/infra/values.yaml
kubectl exec -n infra infra-vault-0 -- vault status
```

Root token is `root` (chart default, not overridden). Reachable at NodePort `31978` (check `kubectl get svc -n infra infra-vault` if it's changed) — but see the NodePort-unreachable-on-macOS bug in [`docs/project-notes/bugs.md`](../../docs/project-notes/bugs.md) before trying to hit it directly from a Mac host; `minikube service infra-vault -n infra` is the workaround.

**Dev mode means ephemeral** — every pod restart wipes all stored secrets. [LocalStack](../localstack/README.md) is the one real workload currently consuming a Vault secret in this cluster; see its README for the Kubernetes-auth wiring pattern used to deliver it.

See [`CLAUDE.md`](CLAUDE.md) for full config, and [`docs/project-notes/bugs.md`](../../docs/project-notes/bugs.md) for the `VAULT_TOKEN` env var gotcha that can silently defeat `vault login`.
