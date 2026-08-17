# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## infra/

Planned home for the `infra` Namespace resource — the shared namespace for observability/infra services (`grafana/`, `prometheus/`, `redis/`, and future additions). **Not yet created** — the user is writing these manifests themselves. See `docs/project-notes/decisions.md` for the namespace rationale and recommended build order. Existing components (`mongodb`, `mongodb-express`, `nginx`) intentionally stay in `default`.
