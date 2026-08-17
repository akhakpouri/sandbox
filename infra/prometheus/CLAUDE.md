# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## prometheus/

Planned: Prometheus in the `infra` namespace. **Not yet created** — the user is writing these manifests themselves. This is the datasource `grafana/` needs, so per `docs/project-notes/decisions.md` it's recommended before Grafana. Once added, note here the scrape config approach (default self-scrape only vs. a mounted `prometheus.yml` with real targets).
