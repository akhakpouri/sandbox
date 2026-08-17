# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## mongodb/

Single-replica MongoDB (official `mongo` image) in the `default` namespace, port 27017. Root credentials come from the `mongodb-secret` Secret (`MONGO_INITDB_ROOT_USERNAME`/`MONGO_INITDB_ROOT_PASSWORD`). Exposed cluster-internally via `mongodb-service` (ClusterIP, port 27017) — `mongodb-express/` depends on this Service name and reuses these same credential values. Apply before `mongodb-express/`.
