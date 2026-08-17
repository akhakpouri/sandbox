# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## nginx/

Two-replica stock `nginx` deployment. **Note:** the Deployment's `containerPort` and the Service's `targetPort` are both set to `8080`, but the stock `nginx` image listens on `80` by default and nothing in this manifest reconfigures it — see `docs/project-notes/bugs.md`. Service exposes port 80 externally, forwarding to `targetPort: 8080`.
