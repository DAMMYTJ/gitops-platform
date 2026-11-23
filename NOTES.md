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

## Phase 2: ArgoCD (OpenTofu + Helm)
- Installed ArgoCD with the OpenTofu helm provider (chart 10.18.2, UI via port-forward on 8081)
- Mistake: put a second required_providers block in argocd.tf, which caused "Duplicate required providers configuration". Fix: one block in main.tf listing both providers.
- Mistake: ran file-creating commands in the repo root, so files landed in the wrong folder. Fix: moved them into infra/tofu/.

## Phase 3: Demo app and GitOps
- Built a real app: web page + FastAPI + MySQL, packaged as one Helm chart with per-environment values (dev, staging, prod)
- App-of-apps: one root Application watches argocd/apps, which holds three child Applications
- MySQL passwords were created with kubectl as Secrets and are never in Git
- Result: all 4 Applications Synced/Healthy; 11 pods running; nodes use about 2.9 GB RAM combined
- Test: deleted the dev web Deployment, and ArgoCD recreated it by itself (self-heal)
- Test: deleted the dev MySQL pod; data persisted on the PersistentVolume
- Lesson: Colima started in the foreground by mistake, so I deleted it and restarted with 4 CPU/6 GB/40 GB
- Lesson: stale shell hash gave the wrong kubectl version; fixed with `hash -r`
