# volumes (unused)

`infra-volume.yaml` defines a PersistentVolume backed by an NFS server (`172.17.0.2:/tmp`) that doesn't exist on this cluster — early scratch/tutorial work, **never applied**. No PVC in this repo targets its `storageClassName: infra`; every real component (`redis`, `prometheus`) uses the `standard` storageClass instead.

Kept for reference (the file's inline comments walk through PV access modes and reclaim policies), not as something to actually deploy.
