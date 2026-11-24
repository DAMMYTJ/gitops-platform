# ADR 0004: Canary releases with Argo Rollouts, split by pod count

Status: Accepted, with a known limitation

## Context
I wanted safer releases than a plain Deployment rolling update, without adding a service mesh to a single-laptop cluster.

## Decision
The API is an Argo Rollout with canary steps 25%, pause 30s, 50%, pause 30s, 100%. Prod runs 4 API pods, so each step is one pod. `progressDeadlineSeconds: 60` and `progressDeadlineAbort: true` abort a release whose new pods never become ready. Rollback is a `git revert`, which ArgoCD applies.

## Consequences
- With no traffic router, the split follows pod count, so it is approximate and not an exact traffic percentage.
- A deliberately broken release (image that does not exist) was aborted after the deadline while the 4 healthy pods kept serving.
- Release 1.1.0 is the same code as 1.0.0 with a new tag; it exercises the release mechanism, not new application behaviour.
- A production setup would add a traffic router (ingress or mesh) and metric-based analysis.
