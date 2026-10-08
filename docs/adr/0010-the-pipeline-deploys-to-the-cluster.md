# ADR 0010: The pipeline deploys to the cluster, with a token the platform republishes

## Status

Accepted

Supersedes ADR 0007 together with ADR 0009. Needs a counterpart ADR in
`vk-lab-platform`, which amends that repository's ADR 0015.

## Context

ADR 0007 states the position this one reverses:

> No credential beyond the workflow token, no cluster access from CI, and
> ADR 0015 holds.

Platform ADR 0015 is the source of that rule: *"CD handoff is a git commit,
not a live cluster call."* It was chosen so the handoff works while the
cluster is torn down — a push and a commit both succeed against nothing, and
Argo catches up at the next `make up`.

ADR 0009 introduces two environments that Argo does not own, and something has
to install them. A Git commit cannot: there is no Argo Application watching
`ahorro-dev` or `ahorro-pr`, and creating one per pull request would need an
ApplicationSet with a GitHub token living in the cluster, which is a larger
exception than this one.

What stands in the way is only the credential. The API server is reachable
from a runner on every target: 6443 is open to `0.0.0.0/0` on civo and
hetzner, by a firewall comment that names GitHub Actions as the reason, and
EKS sets `endpoint_public_access = true`. But `ahorro-ci-role` holds exactly
one permission, `ssm:GetParameter` on `/account/root_domain`, and the
platform's own `lab-role` trusts `repo:savak1990/vk-lab-platform:*`, which a
token from this repository never matches.

## Alternatives

1. **Widen `ahorro-ci-role` to match `lab-role`.** Grant `kms:Decrypt` on the
   secrets key and the cluster SSM paths, and this repository's CI can decrypt
   the provider tokens and build an admin kubeconfig exactly as the platform
   does. Least new code. Rejected: it hands the application repository
   cluster-admin over the whole lab to install two namespaces, against the
   standing rule to prefer the narrower grant.

2. **A long-lived kubeconfig in a GitHub secret.** Simplest to build.
   Rejected on the lifecycle, not the secret: the lab is disposable, so every
   `make up` mints a new certificate authority and new tokens. The secret
   would break on the first rebuild and stay broken, with a failed deployment
   as the only signal.

3. **An Argo CD API token and `argocd app sync` from CI.** Already weighed and
   rejected in ADR 0007 for needing a token in SSM, a platform IAM change and
   an ADR 0015 exception. Two of those three are needed by any option here,
   but it also requires an Argo Application per preview, which is the
   machinery option 4 avoids.

4. **A scoped ServiceAccount whose token the platform republishes.**

## Decision

**Option 4.**

The platform creates an `ahorro-deploy` ServiceAccount with a Role over
`ahorro-dev` and `ahorro-pr` and nothing in `ahorro`. During every bring-up it
mints that ServiceAccount's token and writes it, the cluster certificate
authority and the API endpoint to SSM under
`/<project>/cluster/ahorro-deploy/`. `ahorro-ci-role` gains
`ssm:GetParameter` on that prefix and on
`/<project>/persistent/ahorro-cognito/`.

A job assumes `ahorro-ci-role` through OIDC, reads those parameters, builds a
kubeconfig in the workspace and runs `helm`. Nothing is persisted between
runs. The chain is drawn in `docs/delivery.md` §4.

Republishing on every bring-up is what makes this survive a disposable
cluster, and it is the property option 2 cannot have. The credential is always
as fresh as the cluster it opens.

## Consequences

Platform ADR 0015's handoff rule no longer holds for this application, and
saying so is the point of the counterpart ADR in that repository. The reason
0015 gave — that a commit succeeds while the cluster is down — still applies
to `ahorro`, which Argo continues to own and which a commit continues to
drive. Only the two pipeline-owned environments make a live call, and a live
call against a cluster that is down should fail.

The blast radius is two namespaces. The ServiceAccount cannot read, write or
delete anything in `ahorro`, so the released environment is safe from the
pipeline by RBAC rather than by convention.

The platform now owns a piece of this application's delivery, which the
boundary in ADR 0003 would otherwise keep out. That is consistent with it:
identity and cluster access are the platform's to grant, and the grant is a
pull request against that repository, as every other one has been.

A deployment attempted while the cluster is down fails at the kubeconfig. That
is correct and needs no special handling, but it is a louder failure mode than
the commit-based handoff it replaces.

All three environments share one Cognito user pool and one app client, because
there is one of each per platform project by deliberate design — the API
verifier pins a single client id. `ahorro-dev` therefore signs in for real,
which is the check a release most needs beforehand.
