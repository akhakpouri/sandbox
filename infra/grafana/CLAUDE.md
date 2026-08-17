# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## grafana/

Planned: Grafana in the `infra` namespace. **Not yet created** — the user is writing these manifests themselves. Per `docs/project-notes/decisions.md`, deploy this last — it's only useful once `prometheus/` exists to point at as a datasource. Once added, note here the datasource wiring (e.g. `prometheus-service.infra.svc.cluster.local:9090`) and whether the default `admin`/`admin` login was locked down via `GF_SECURITY_ADMIN_PASSWORD`.
