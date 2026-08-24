# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Local development suite of Kubernetes manifests and Helm-chart deployments for a local cluster (minikube) — started as a sandbox for learning core K8s primitives by hand, and has grown into an actual local dev platform: AWS service emulation (LocalStack), secrets management (Vault), observability (Prometheus + Grafana), a cache/broker (Redis), with GitOps (ArgoCD) planned next. Components are either plain per-directory YAML applied with `kubectl apply -f <dir>/`, or installed via their official Helm chart with a `values.yaml` override — see `docs/project-notes/decisions.md` for which approach each component uses and why. Each component directory carries a `CLAUDE.md` (deep reference: exact config, gotchas); everything under `infra/` also carries a `README.md` (human-facing quick start).

**Layout doesn't map 1:1 onto a `default`/`infra` namespace split, despite appearances:**
- `db/mongodb/` — MongoDB manifests, `default` namespace. Not currently applied to the cluster.
- `dashboard/` — the Kubernetes Dashboard ingress, plus a nested `mongodb-express/` (MongoDB's web UI). Also not currently applied.
- `infra/` — the namespace for platform/observability tooling. `redis/`, `prometheus/` (kube-prometheus-stack, bundled Grafana), `vault/`, and `localstack/` are real and deployed. `nginx/` and `volumes/` inside `infra/` are early scratch/tutorial exercises that were never wired into anything — present as files, not deployed; their `README.md`s say so.

**Not tracked in this repo at all:** a `postgres` StatefulSet running in a `database` namespace, deployed out-of-band with no matching manifest anywhere in git. Noted here so it isn't mistaken for orphaned cluster state — this repo doesn't manage it.

Expect `infra/` to keep growing — each new platform component gets its own subdirectory with a `CLAUDE.md` and `README.md`. See `docs/project-notes/decisions.md` for build order and reasoning.

## Commands

There's no unified build/lint/test/deploy tooling — components are either plain YAML applied directly with `kubectl`, or installed via Helm with a `values.yaml` override; check each component's `CLAUDE.md`/`README.md` for which.

- Apply a plain-YAML component: `kubectl apply -f <dir>/` (e.g. `kubectl apply -f infra/redis/`)
- Remove one: `kubectl delete -f <dir>/`
- Install/upgrade a Helm-based component: `helm install|upgrade <release> <chart> -n infra -f infra/<component>/helm/infra/values.yaml` — see that component's `CLAUDE.md` for the exact chart/release name.
- Check status: `kubectl get pods,svc -A`
- Validate a manifest without applying: `kubectl apply --dry-run=client -f <dir>/`

## Architecture

- **No shared namespace convention across the whole repo.** `db/mongodb/` and `dashboard/` (including its nested `mongodb-express/`) target `default`; the dashboard ingress targets the `kubernetes-dashboard` namespace (assumes the Dashboard itself is already installed there — this repo only adds the Ingress); everything under `infra/` targets the `infra` namespace. As of now, `default` has nothing actually applied to it — mongodb/mongodb-express manifests exist but aren't deployed.
- **mongodb + mongodb-express is a dependent pair.** `mongodb-express` (at `dashboard/mongodb-express/`) is a web UI client for `mongodb` (at `db/mongodb/`): its ConfigMap points `database_url` at the `mongodb-service` Service name, and it authenticates using the same credential values as `mongodb-secret`. Apply `db/mongodb/` before `dashboard/mongodb-express/`.
- **Secrets are base64, not encrypted**, matching plain `kubectl create secret`/manifest conventions — treat every `secret.yaml` in this repo as sandbox-only, never production credentials. This extends to non-`secret.yaml` credentials too (e.g. Vault's dev-mode root token, chart-generated admin passwords) — none of it is meant to be real.
- **No Ingress controller config lives here** beyond the dashboard rule — `dashboard.local` requires an Ingress controller running on the cluster and a local hosts-file entry pointing it at the ingress IP.
- **`infra` namespace holds platform/observability tooling** (`redis`, `prometheus` + bundled `grafana`, `vault`, `localstack`, ...), kept separate from the app-ish components elsewhere. See `docs/project-notes/decisions.md` for the namespace rationale and build order.

Tracked issues, decisions, and facts about this repo live in `docs/project-notes/` — check there before assuming something is a bug vs. an intentional sandbox shortcut.

## Project Memory System

### Memory-Aware protocols

**Before proposing architectural changes:**
- Check `docs/project-notes/decisions.md` for existing decisions.
- Verify the proposed approach doesn't conflict with past choices.

**When encountering errors or bugs:**
- Search `docs/project-notes/bugs.md` for similar issues.
- Apply known fixes if found.
- Document new bugs and solutions once resolved.

**When looking up project configuration:**
- Search `docs/project-notes/facts.md` for ports, service names, namespaces, image references, and other configuration.
- Prefer documented facts over assumptions.
