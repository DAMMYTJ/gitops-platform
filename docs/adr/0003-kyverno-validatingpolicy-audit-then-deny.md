# ADR 0003: Kyverno ValidatingPolicy (CEL), rolled out in Audit before Deny

Status: Accepted

## Context
I wanted policy-as-code to block unsafe workloads: containers running as root, containers without memory limits, and images tagged `latest`. My first version used the legacy `kyverno.io/v1` ClusterPolicy. Kyverno v1.20 rejected it and ArgoCD showed the error.

## Decision
Rewrite the three policies as `policies.kyverno.io/v1` ValidatingPolicy objects with CEL expressions. Start with `validationActions: [Audit]`, fix what the policy report finds, then switch to `[Deny]`.

## Consequences
- Audit mode found a real problem: the official MySQL image starts as root and failed require-non-root in all three environments. I fixed the chart (user and group 999, fsGroup 999, all capabilities dropped) and the data survived.
- Only after the report was clean did I enforce, so enforcement did not break running workloads.
- Policies apply to dev, staging and prod only, not to system namespaces.
- Kyverno reports only the first failing policy in a rejection message, so each policy was tested separately.
