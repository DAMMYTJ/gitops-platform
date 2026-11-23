# Build Notes

Running log of what I did, why, and what broke. Used later to write the README and ADRs.

## Phase 0: Tools
- Git identity set to GitHub noreply email so commits stay private
- GitHub CLI (gh) installed and logged in
- Created repos: gitops-platform, gitops-demo-app

## Decisions
- Public repos: ArgoCD can read them without credentials
- Colima instead of Docker Desktop: free, no license limits

## What broke and how I fixed it
- (nothing yet)

## Phase 1 done (23 Nov 2026)
- Cluster defined as code in infra/k3d-cluster.yaml (pinned k3s v1.36.4); deleted and rebuilt it from the file to prove it works
- Decision: community k3d providers for OpenTofu are old and unreliable, so the cluster comes from the k3d config file and OpenTofu manages what is inside it
- OpenTofu (kubernetes provider v3.5.0) created dev, staging and prod namespaces; plan showed 3 to add, 0 to change, 0 to destroy
- Fixed: ran cd with a relative path from the wrong folder; used the full path and pwd instead
- State file and .terraform stay out of Git via .gitignore; the lock file is committed
