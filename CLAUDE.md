# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Personal sandbox of raw Kubernetes manifests for infra components run on a local cluster. Each subdirectory is a self-contained component (Deployment/Service/Secret/ConfigMap/Ingress) — there is no Helm, Kustomize, or CI wiring them together. Current, deployed components: `mongodb`, `mongodb-express` (web UI for mongodb), `nginx`, and a `dashboard` ingress for the Kubernetes Dashboard — all in the `default` namespace. Planned next: `redis`, `prometheus`, `grafana` (and eventually `otel`) in a dedicated `infra` namespace — directories exist with a `CLAUDE.md` each, but the manifests themselves are being written by hand, not scaffolded. See `docs/project-notes/decisions.md` for the reasoning and recommended build order. Expect this to grow — each new product gets its own subdirectory with its own `CLAUDE.md`.

## Commands

There is no build/lint/test tooling — this repo is plain YAML manifests applied directly with `kubectl`.

- Apply one component: `kubectl apply -f <dir>/`
- Remove one component: `kubectl delete -f <dir>/`
- Apply everything: `kubectl apply -f mongodb/ -f mongodb-express/ -f nginx/ -f dashboard/` (apply `mongodb/` before `mongodb-express/` — see Architecture)
- Check status: `kubectl get pods,svc -A`
- Validate a manifest without applying: `kubectl apply --dry-run=client -f <dir>/`

## Architecture

- **No shared namespace convention yet.** Everything except the dashboard ingress deploys to `default`. The dashboard ingress targets the `kubernetes-dashboard` namespace, which assumes the Kubernetes Dashboard is already installed there — this repo only adds the Ingress for it, not the Dashboard itself.
- **mongodb + mongodb-express is a dependent pair.** `mongodb-express` is a web UI client for `mongodb`: its ConfigMap (`mongo-express-configmap`) points `database_url` at the `mongodb-service` Service name, and it authenticates using the same credential values as `mongodb-secret`. Apply `mongodb/` before `mongodb-express/`.
- **Secrets are base64, not encrypted**, matching plain `kubectl create secret`/manifest conventions — treat every `secret.yaml` in this repo as sandbox-only, never production credentials.
- **No Ingress controller config lives here** beyond the dashboard rule — `dashboard.local` requires an Ingress controller running on the cluster and a local hosts-file entry pointing it at the ingress IP.
- **`infra` namespace is planned for observability/infra tooling** (`redis`, `prometheus`, `grafana`, ...), kept separate from the app-ish components in `default`. The `infra/`, `redis/`, `prometheus/`, and `grafana/` directories currently hold only a `CLAUDE.md` each — no manifests yet, the user is writing those. See `docs/project-notes/decisions.md` for the namespace rationale and recommended build order once they're added.

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
