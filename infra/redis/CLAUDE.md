# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## redis/

Redis in the `infra` namespace, deployed as a single-replica Deployment (planned to move to a StatefulSet later). `configmap.yaml` (`redis-app`), `pvc.yaml` (`redis-pvc`), `deployment.yaml`, and `service.yaml` (`redis-service`, NodePort) are all applied. See `docs/project-notes/decisions.md` for why this was stood up first in `infra` (zero dependencies, good namespace/networking smoke test).

- **Persistence: configured.** `redis-pvc` (250Mi, `standard` storageClass) is mounted at `/data`; `redis.conf` sets `appendonly yes` for AOF persistence.
- **Auth: not configured.** No `requirepass` set — the stock `redis` image has none by default, and this hasn't been added yet. Redis is reachable, unauthenticated, from anything that can hit `redis-service` in the `infra` namespace. Sandbox-acceptable for now; revisit before treating this as anything more than local/sandbox.
- ConfigMap volume mount gotcha: `deployment.yaml`'s `volumeMounts` reference pod-local volume names (`redis-config`, `redis-pvc`) that must have matching entries in `spec.template.spec.volumes` — easy to forget when hand-writing the Deployment, since the API error ("Not found") is about the missing `volumes:` entry, not the ConfigMap/PVC objects themselves.
- Editing `redis.conf` in `configmap.yaml` doesn't restart the pod — `kubectl apply` the ConfigMap, then `kubectl rollout restart deployment/redis-deployment -n infra` to pick it up.
