# ADR 0005: OpenTofu bootstraps ArgoCD, then ArgoCD runs everything else (app of apps)

Status: Accepted

## Context
Something has to install ArgoCD before ArgoCD can manage anything. I wanted a clear split between one-time bootstrap and continuous delivery.

## Decision
OpenTofu installs ArgoCD, Kyverno and Argo Rollouts with Helm. One `root` Application is applied by hand once; it watches `argocd/apps/`, which holds the Applications for dev, staging, prod and the policies. Adding or removing a file in that folder adds or removes an app, with prune and self-heal on.

## Consequences
- Day-to-day changes are Git commits only. Deleting a Deployment by hand is reverted by ArgoCD (tested).
- One chart and three values files serve all environments, so differences between environments are visible in Git.
- The repos are public so ArgoCD needs no credentials. A private setup would add a repository credential.
- ArgoCD and Kyverno chart versions are not yet pinned in OpenTofu (to do).
