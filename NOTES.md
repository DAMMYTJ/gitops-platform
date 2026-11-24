# Build notes

My personal log for this project. I'm keeping track of what I've done, why I made certain decisions, and what went wrong along the way. I'll use these notes later when putting together the README and ADRs.

## Phase 0: tools
- Set my git email to the GitHub noreply address so my personal email doesn't show up in my commits
- Installed GitHub CLI (`gh`) and logged in
- Created two repos: `gitops-platform` and `gitops-demo-app`
- Made both repos public so ArgoCD can read them without needing credentials
- Decided to use Colima instead of Docker Desktop because it's free

## Phase 1 (23 Nov 2026): the cluster
- Set up the cluster in `infra/k3d-cluster.yaml` with k3s v1.36.4 pinned. I deleted the cluster and rebuilt it using the same file just to make sure it worked
- Looked into the k3d providers for OpenTofu, but most of them seemed outdated and weren't well maintained. I decided to skip them. k3d creates the cluster from the config file, and OpenTofu manages what's inside it
- Used OpenTofu to create the dev, staging and prod namespaces. The plan showed 3 to add, 0 to change and 0 to destroy
- Mistake: I ran `cd` with a relative path while I was in the wrong folder. I fixed it by using the full path and checking my location with `pwd`
- Added the state file and `.terraform` to `.gitignore`. Kept the lock file committed

## Phase 2: ArgoCD
- Installed ArgoCD through OpenTofu and Helm (chart 10.18.2). I access the UI using port-forwarding on 8081
- Mistake: I added a second `required_providers` block in `argocd.tf`, which made `tofu init` fail with "Duplicate required providers configuration". Fixed it by keeping everything in one block in `main.tf`
- Mistake: I ran the commands to create some files from the repo root, so they ended up in the wrong folder. Moved them into `infra/tofu/`

## Phase 3: the demo app
- Built an actual app with a web page, FastAPI and MySQL, all packaged into one Helm chart with separate values files for dev, staging and prod
- Set up one root Application in ArgoCD to watch `argocd/apps`, where I keep the three child Applications
- Initially created the MySQL passwords manually using `kubectl` so they wouldn't end up in Git (I changed this later in Phase 5)
- All 4 Applications showed as Synced and Healthy, with 11 pods running. The two nodes were using around 2.9 GB of RAM combined
- Test: manually deleted the dev web Deployment to see what would happen. ArgoCD picked it up and recreated it by itself
- Test: deleted the dev MySQL pod and checked if the data was still there afterwards. It was
- Mistake: I accidentally started Colima in the foreground. I deleted it and started it again with 4 CPUs, 6 GB RAM and 40 GB disk
- Mistake: my shell was still using an old cached `kubectl` path and showing the wrong version. Fixed it by running `hash -r`

## Phase 4: Kyverno policies
- Installed Kyverno using OpenTofu. Created three policies in `policies/` that ArgoCD deploys: `require-non-root`, `require-memory-limits` and `disallow-latest-tag`
- Mistake: I initially wrote the policies using the old `kyverno.io/v1 ClusterPolicy` format. Kyverno 1.20 didn't accept it, so I rewrote all three using `ValidatingPolicy` with CEL expressions
- Mistake: I hadn't created the ArgoCD Application file for the policies, so the root Application wasn't picking them up. I found the issue by comparing the revision ArgoCD was using with `git rev-parse HEAD`
- Started with Audit mode to see what would fail first. The policy report showed MySQL failing `require-non-root` in all 3 environments because the official image starts as root
- Fixed it in the chart by running MySQL as user 999, setting `runAsNonRoot` and `fsGroup` to 999, and dropping all capabilities. The existing data was still there afterwards
- Once everything was working, I switched the policies from Audit to Deny. Pods using the `latest` tag, running as root or without memory limits were rejected, while a compliant pod was accepted
- Kyverno only showed the first failing policy in its rejection message, so I tested each one separately using dry runs (`t-latest`, `t-root` and `t-good`)
- Next time, I'll use a hard refresh in ArgoCD (`argocd.argoproj.io/refresh=hard`) instead of waiting for the next poll

## Phase 5: secrets
- Generated an age key pair. I kept the private key outside the repo and made a backup. `infra/tofu/.sops.yaml` is configured to encrypt only the password values in `secrets.enc.yaml`, so I can safely push the file to Git
- OpenTofu uses the `carlpett/sops` provider to decrypt the file when I run apply and create the Kubernetes Secrets. I went with this instead of an ArgoCD SOPS plugin because that would require a customised repo-server. The downside is that the decrypted values are stored in my local state file, which is gitignored
- Kept the existing passwords on purpose. MySQL only reads them when it first creates its data folder, so changing them could have caused problems with the existing databases
- Used an import block to bring the existing Secrets under OpenTofu management instead of recreating them. The plan only showed small changes related to provider defaults, and the secret data stayed the same
- Test: manually deleted the staging Secret, ran `tofu apply`, and watched it get recreated from the encrypted file. Staging was still working afterwards
- Mistake: opened a new terminal tab and SOPS failed with "0 successful groups" because `SOPS_AGE_KEY_FILE` wasn't set. Fixed it with `export SOPS_AGE_KEY_FILE=$HOME/.config/sops/age/keys.txt` and added it to `~/.zshrc` so I wouldn't run into the same issue again
- Always check the plan properly, especially anything that says destroy, before applying

## Phase 6: Argo Rollouts
- Installed Argo Rollouts and its dashboard using OpenTofu. Homebrew couldn't build the kubectl plugin because my Xcode tools were outdated, so I downloaded the prebuilt binary instead of using sudo
- Changed the API Deployment into a Rollout in the Helm chart. Canary steps are 25%, 50% and 100%, with a 30-second pause between each. Prod has 4 API pods, so each step moves one pod. There's no service mesh yet, so traffic is split by pod count. That's one of the current limitations
- Released API 1.1.0 to prod through Git. It's the same code as 1.0.0, just with a new tag and version label. I only wanted to test the release process
- Released a broken 1.2.0 on purpose using an image that doesn't exist. The new pod never became ready, the Rollout aborted after the 60-second deadline, and the 4 healthy pods kept serving the application
- Rolled it back using `git revert`, and ArgoCD brought the Rollout back to Healthy
- Mistake: I started watching my first canary rollout after it had already finished, so I missed the part where both old and new versions were running. Next time, I'll start the watch before pushing the change

## Wrap-up
- Went through my screenshots and organised 36 of them inside `docs/evidence`, with one folder for each phase.
- Finished writing the README, the architecture diagram and 5 ADRs in `docs/`
- Added the known limitations to the README so it's clear what the project currently covers and what still needs improvement (local cluster, canary releases based on pod count, same-code 1.1.0 release, secrets in local state, one MySQL instance per environment, and Helm chart versions not pinned yet)
