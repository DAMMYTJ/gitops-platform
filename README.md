# gitops-platform

A GitOps platform built from scratch on a single laptop (MacBook Pro M1, 16 GB), using only free tools. A real three-tier app (web, FastAPI, MySQL) runs in three environments on Kubernetes, with every change flowing through Git.

## How I built this

I built this as a guided learning project, working step by step with Claude (an AI assistant) as a tutor and pair programmer. Claude suggested commands and drafted much of the YAML, Helm and OpenTofu code. I ran every command on my own machine, hit the errors, diagnosed and fixed them, and made the design choices recorded in the ADRs. `NOTES.md` is my running log (including mistakes), and `docs/evidence/` holds my screenshots from each phase.

Application code lives in a separate repo: [gitops-demo-app](https://github.com/DAMMYTJ/gitops-demo-app).

## What it demonstrates

- **Kubernetes cluster as code:** k3d cluster from a config file with a pinned k3s version; deleted and rebuilt to prove it.
- **Infrastructure as code with OpenTofu:** namespaces, ArgoCD, Kyverno, Argo Rollouts and Secrets via the kubernetes and helm providers, with the lock file committed and state kept out of Git.
- **GitOps with ArgoCD:** app-of-apps pattern, automated sync with prune and self-heal. Deleting a Deployment by hand is reverted automatically.
- **One Helm chart, three environments:** dev, staging and prod differ only in values files (prod runs 2 web and 4 API pods).
- **Policy as code with Kyverno:** three admission policies (no root, memory limits required, no `latest` tag), rolled out in Audit mode first, then enforced.
- **Encrypted secrets in Git:** SOPS + age, decrypted by OpenTofu at apply time. A deleted Secret was rebuilt from the encrypted file.
- **Progressive delivery with Argo Rollouts:** canary release (25%, 50%, 100%) with automatic abort of a broken release and rollback through `git revert`.
- **Pod hardening:** non-root users, all Linux capabilities dropped, privilege escalation off.

## Architecture

See [docs/architecture.md](docs/architecture.md) for the diagram.

```
Git push -> GitHub -> ArgoCD -> dev / staging / prod
                         ^           ^
        OpenTofu bootstraps          Kyverno checks every pod
        ArgoCD, Kyverno, Rollouts,   Argo Rollouts runs the canary
        namespaces and Secrets
```

| Layer | Tool |
|---|---|
| Local VM and containers | Colima, Docker |
| Kubernetes | k3d (k3s v1.36.4), Traefik ingress |
| Infrastructure as code | OpenTofu 1.13 |
| Packaging | Helm |
| GitOps | ArgoCD (chart 10.18.2) |
| Policy | Kyverno 1.20 (ValidatingPolicy, CEL) |
| Secrets | SOPS + age |
| Releases | Argo Rollouts (chart 2.43.12) |

## Design decisions

Short records of the choices and their trade-offs are in [docs/adr](docs/adr):

1. [Cluster from a k3d config, contents managed by OpenTofu](docs/adr/0001-cluster-from-k3d-config-not-opentofu.md)
2. [SOPS + age secrets decrypted by OpenTofu](docs/adr/0002-sops-age-decrypted-by-opentofu.md)
3. [Kyverno ValidatingPolicy, Audit before Deny](docs/adr/0003-kyverno-validatingpolicy-audit-then-deny.md)
4. [Replica-based canary with auto-abort](docs/adr/0004-replica-based-canary-with-auto-abort.md)
5. [OpenTofu bootstraps ArgoCD, app of apps does the rest](docs/adr/0005-argocd-app-of-apps-bootstrapped-by-opentofu.md)

## Things that went wrong (and what I learned)

- Wrote Kyverno policies in the legacy ClusterPolicy format. Kyverno 1.20 rejected them, so I migrated to ValidatingPolicy.
- Audit mode showed the official MySQL image fails the non-root policy. I fixed the chart before enforcing.
- A missing ArgoCD Application file meant the policies never deployed. I found it by comparing the revision ArgoCD read with `git rev-parse HEAD`.
- A duplicate `required_providers` block broke `tofu init`.
- A decryption error in a new terminal tab came from a missing `SOPS_AGE_KEY_FILE` variable.

More in [NOTES.md](NOTES.md).

## Evidence

Screenshots by phase, in [docs/evidence](docs/evidence):

| Phase | What it shows |
|---|---|
| 0 | Tools installed, Colima VM running |
| 1 | Cluster rebuilt from config, namespaces created by OpenTofu |
| 2 | ArgoCD installed by OpenTofu |
| 3 | App in three environments, self-heal, database persistence |
| 4 | Kyverno policies: audit finding, then enforcement |
| 5 | Secret deleted and rebuilt from the encrypted file |
| 6 | Canary release, aborted bad release, rollback |

## Repository layout

```
infra/k3d-cluster.yaml   cluster definition
infra/tofu/              OpenTofu: namespaces, ArgoCD, Kyverno, Rollouts, secrets
argocd/                  root app and the child Applications
apps/demo-app/           Helm chart and values for dev, staging, prod
policies/                Kyverno ValidatingPolicy files
docs/                    architecture, ADRs, evidence
NOTES.md                 build log
```

## Rebuild it

Needs macOS or Linux with Homebrew. Install `colima docker k3d kubectl helm opentofu sops age`, then:

```
colima start --cpu 4 --memory 6 --disk 40
k3d cluster create --config infra/k3d-cluster.yaml
# build the demo images from gitops-demo-app, then:
k3d image import demo-api:1.0.0 demo-api:1.1.0 demo-web:1.0.0 -c platform-lab
cd infra/tofu
export SOPS_AGE_KEY_FILE=$HOME/.config/sops/age/keys.txt
tofu init && tofu apply
kubectl apply -f ../../argocd/root-app.yaml
```

You need your own age key: replace the recipient in `infra/tofu/.sops.yaml` and re-encrypt `secrets.enc.yaml` with your own passwords. The one in this repo can only be opened with my private key, which is not published. On a fresh cluster, remove the one-time `import` block in `secrets.tf` first.

## Known limitations

- Local k3d cluster on one machine, not a cloud cluster. Traefik replaces a cloud load balancer, and there is no high availability.
- Canary traffic is split by pod count, not by exact percentage, because there is no service mesh or traffic router.
- Release 1.1.0 is the same code as 1.0.0 with a new tag; it demonstrates the release process, not new features.
- Decrypted secrets sit in the local, gitignored OpenTofu state.
- One MySQL instance per environment, with no replication or backups.
- ArgoCD and Kyverno chart versions are not yet pinned in OpenTofu.
- Images are built locally and imported into k3d; there is no registry or CI pipeline yet (the next project covers that).

## Next

An SRE layer (observability, SLOs, chaos tests) and a secure CI/CD supply chain (image scanning, SBOM, signing) on top of this platform.
