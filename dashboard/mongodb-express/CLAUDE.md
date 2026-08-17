# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## mongodb-express/

Web UI (`mongo-express` image) for the `mongodb/` deployment, port 8081. `mongo-express-configmap` points `ME_CONFIG_MONGODB_SERVER` at `mongodb-service` and toggles basic auth off (`basic_auth: "false"`). `mongo-express-secret` currently holds the same values as `mongodb/secret.yaml` so the UI can authenticate as the Mongo root user (see `docs/project-notes/decisions.md`). Exposed via a `LoadBalancer` Service with a fixed `nodePort: 30000`. Requires `mongodb/` to be applied first.
