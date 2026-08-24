# Redis

Single-replica Redis (stock `redis` image) in the `infra` namespace — the cache/broker layer of this local dev suite. Deployed as plain YAML, with AOF persistence and a Prometheus exporter sidecar already wired in.

## Quick start

```
kubectl apply -f infra/redis/
kubectl get pods -n infra -l app=redis-app
```

Connect from inside the cluster at `redis-service.infra.svc.cluster.local:6379` (no `requirepass` set — sandbox only). Metrics are scraped automatically by Prometheus via the `sm-redis` ServiceMonitor — no extra wiring needed.

See [`CLAUDE.md`](CLAUDE.md) for persistence details, a ConfigMap/volume-mount gotcha worth knowing before editing the Deployment, and how to pick up a `redis.conf` change.
