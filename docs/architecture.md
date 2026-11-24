# Architecture

```mermaid
flowchart TB
  dev([Engineer on a MacBook]) -->|git push| gh[(GitHub: gitops-platform)]
  dev -.->|tofu apply| tofu[OpenTofu]
  dev -.->|k3d cluster create --config| k3d[k3d cluster config]

  subgraph mac[MacBook Pro M1 - Colima VM, Docker]
    subgraph cluster[k3d cluster: platform-lab - 1 server, 1 agent, Traefik ingress]
      argocd[ArgoCD]
      root[root app - app of apps]
      kyverno[Kyverno - admission policies]
      rollouts[Argo Rollouts - canary]
      subgraph envs[Application environments]
        d[dev namespace]
        s[staging namespace]
        p[prod namespace]
      end
    end
  end

  k3d --> cluster
  tofu -->|installs via Helm| argocd
  tofu -->|installs via Helm| kyverno
  tofu -->|installs via Helm| rollouts
  tofu -->|namespaces and Secrets, decrypted with SOPS + age| envs
  gh -->|ArgoCD pulls and syncs| argocd
  argocd --> root --> d
  root --> s
  root --> p
  root -->|policies/| kyverno
  kyverno -.->|admission webhook: deny root, latest tag, no memory limit| envs
  rollouts -->|25%, 50%, 100% canary, auto abort| p
```

## Who owns what

| Layer | Tool | Source of truth |
|---|---|---|
| Cluster | k3d | `infra/k3d-cluster.yaml` |
| Cluster add-ons and secrets | OpenTofu | `infra/tofu/*.tf`, `secrets.enc.yaml` |
| Applications and policies | ArgoCD | `argocd/`, `apps/`, `policies/` |
| Releases | Argo Rollouts | `apps/demo-app/templates/api.yaml` |

## Request path

Browser or curl, then `*.localhost:8080`, then the k3d load balancer, then Traefik ingress, then the web or API service in the matching namespace, then MySQL (one instance per environment, on a PersistentVolume).
