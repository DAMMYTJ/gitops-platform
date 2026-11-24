# ADR 0001: Create the cluster from a k3d config file, manage its contents with OpenTofu

Status: Accepted

## Context
I wanted the whole platform reproducible. OpenTofu can create k3d clusters only through community providers, and the ones I found were old and not well maintained.

## Decision
The cluster is defined in `infra/k3d-cluster.yaml` (k3s version pinned) and created with `k3d cluster create --config`. OpenTofu starts after the cluster exists and manages what is inside it: namespaces, ArgoCD, Kyverno, Argo Rollouts and Secrets.

## Consequences
- Fewer moving parts and no dependency on an unmaintained provider.
- Rebuild is two steps (create the cluster, then `tofu apply`) instead of one.
- I proved the config works by deleting and recreating the cluster.
- In a real cloud environment OpenTofu would own the cluster too (for example EKS); this split is specific to a local lab.
