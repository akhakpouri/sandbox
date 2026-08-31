# Intent: Hello World Kubernetes Operator (Go)

## Problem

This repo runs several platform components that are themselves CRD-plus-operator
systems — `kube-prometheus-stack`'s Prometheus Operator today, CloudNativePG
planned next (see `docs/project-notes/decisions.md`, 2026-08-25 entry) — but
everything in this repo so far has only ever *consumed* the operator pattern,
never *written* one. The goal is to learn how a Go Kubernetes operator actually
works, hands-on, starting from the smallest possible example rather than
jumping straight into an operator that also has to be a useful platform
component.

## Proposed Outcome

A `kubebuilder`-scaffolded Go operator, in a new `operators/hello-world-operator/`
directory:

- API group `hello.akhakpouri.dev/v1`, kind `HelloWorld`, with `spec.message string`.
- One controller (`HelloWorldReconciler`) that, on create/update of a `HelloWorld`,
  creates-or-updates a child `ConfigMap` named `<hw-name>-greeting` holding
  `data.message = spec.message`, sets an `OwnerReference` back to the `HelloWorld`
  (so deleting the CR garbage-collects the ConfigMap), and writes
  `status.observedGeneration` / `status.configMapRef`.
- Run as a local Go process against the existing minikube cluster
  (`make install && make run`) — no container image involved.

**Definition of done:** the kubebuilder-generated `envtest` suite includes one
passing test that creates a `HelloWorld` and asserts the owned `ConfigMap`
appears with the correct data and an `OwnerReference` pointing back to it.

## Affected Users and Systems

Solely a personal learning exercise for the repo owner — not a shared platform
component, no other consumers.

- **This repo**: adds a new top-level `operators/` directory, parallel to
  `infra/`, `db/`, `dashboard/`. This is the first actual application source
  code the repo has held — everything under `infra/` to date is manifests and
  Helm `values.yaml` overrides, never source that gets built.
- **Local toolchain**: Go (1.27, already installed), and `kubebuilder`
  (not yet installed — needs `brew install kubebuilder`).
- **Local cluster**: the existing minikube cluster (Docker driver, already
  running) — the controller connects to it via the current kubeconfig context
  while running locally, no separate cluster needed.

## Constraints

- **Tooling: `kubebuilder`**, not `operator-sdk` or a hand-rolled
  `controller-runtime` setup — the standard Go operator scaffolder, generates
  CRD types/controller stub/RBAC from kubebuilder markers, built on the same
  `controller-runtime` library the real operators this repo runs are built on.
- **Explicitly out of scope for this intent** (deferred, not rejected):
  building a container image, deploying the operator in-cluster as a
  `Deployment`, and wiring it into ArgoCD (`infra/argocd/apps/`) the way every
  other component in `infra/` is managed. Those become a separate, later
  intent if this is continued past the learning stage.
- **Location**: new top-level `operators/hello-world-operator/`, not nested
  under `infra/` — keeps the "manifests/values only" meaning of `infra/` intact.

## Open Questions

- Whether/when to extend this into a containerized, in-cluster-deployed,
  ArgoCD-managed operator — deliberately not decided here, revisit only if
  the learning exercise continues past a working local reconcile loop.
- `hello.akhakpouri.dev` is a placeholder API group domain for this exercise,
  not a considered choice — cheap to rename later if it matters.
