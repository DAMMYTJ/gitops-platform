# ADR 0002: Encrypt secrets with SOPS + age and decrypt them in OpenTofu

Status: Accepted

## Context
Database passwords must not be in Git in plain text, but the platform should still rebuild from the repo. Options considered: an ArgoCD SOPS plugin, Sealed Secrets, External Secrets (needs an external secret store), or SOPS decrypted by OpenTofu.

## Decision
`infra/tofu/secrets.enc.yaml` is encrypted with SOPS and an age key (only the password values are encrypted, via `.sops.yaml`). The `carlpett/sops` OpenTofu provider decrypts it at apply time and creates the Kubernetes Secrets.

## Consequences
- The encrypted file is safe in a public repo; the age private key stays outside Git.
- No customised ArgoCD repo-server is needed.
- Trade-off: decrypted values are stored in the local OpenTofu state, which is gitignored. A team setup would use a remote encrypted state backend.
- I kept the existing passwords on purpose, because MySQL reads them only when its data folder is first created. Existing Secrets were adopted with an `import` block instead of being recreated.
- Proof: I deleted a Secret by hand and `tofu apply` rebuilt it from the encrypted file.
