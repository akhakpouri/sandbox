# k8s-sandbox

A local development suite built on Kubernetes — a personal cluster (minikube) running the pieces a real app stack usually needs: a cache/broker, secrets management, AWS-service emulation for local testing, and observability, all reproducible from manifests and Helm values checked into this repo.

## What's running (`infra` namespace)

| Component | What it's for |
|---|---|
| [Redis](infra/redis/README.md) | Cache / broker |
| [Prometheus + Grafana](infra/prometheus/README.md) | Metrics & dashboards |
| [Vault](infra/vault/README.md) | Secrets management |
| [LocalStack](infra/localstack/README.md) | Local AWS emulation (SQS, SNS) |

MongoDB + its web UI (`mongo-express`) and a Kubernetes Dashboard ingress also live in this repo (`db/mongodb/`, `dashboard/`), but aren't currently applied to the cluster. ArgoCD (GitOps) is planned next — see `docs/project-notes/decisions.md`.

## How it's built

No Helm-everything, no Kustomize, no CI gluing it together — each component is either:
- plain YAML applied with `kubectl apply -f <dir>/`, or
- an official Helm chart with a `values.yaml` override

See [`docs/project-notes/decisions.md`](docs/project-notes/decisions.md) for which approach each component uses and why, [`docs/project-notes/facts.md`](docs/project-notes/facts.md) for exact ports/images/namespaces, and [`docs/project-notes/bugs.md`](docs/project-notes/bugs.md) for known gotchas already hit and fixed.

Full operational detail for each component (and for Claude Code or any AI agent working in this repo) lives in that directory's `CLAUDE.md`.
