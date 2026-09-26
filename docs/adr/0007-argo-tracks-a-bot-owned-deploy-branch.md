# ADR 0007: Argo tracks a bot-owned `deploy` branch; the deploy button is a Git push

## Status

Accepted

Amends core spec 060 requirements 5 and 8 and core spec 030 requirement 6.

## Context

Two things were decided at once and collided. `main` gets branch protection
with a required status check, so that squash-and-merge is the only way onto
it. And core 060 had the release workflow commit the new image SHA into
`gitops/values.yaml` on `main` with a `[skip ci]` message. A push whose
commits carry no passing check run is rejected by protection, and
`enforce_admins` removes the bypass, so the second could never work once the
first was on.

A second requirement arrived at the same time: a button that deploys a pull
request's branch to the lab before merge.

Platform ADR 0015 fixes the boundary: "CD handoff is a git commit, not a
live cluster call." This repository's CI role holds one `ssm:GetParameter`
and no path to the cluster, by design.

Alternatives, in the order they were weighed:

1. **A GitHub App as a ruleset bypass actor.** Keeps 060 as written. Adds a
   long-lived private key to repository secrets, which this repository has
   refused so far, and does nothing for the button.
2. **A moving image tag** (`ahorro-api:main`) with no values commit, which
   ADR 0006 shipped. Satisfies "deploy at cluster boot" and needs no push at all. But a new image under
   the same tag changes no manifest, so neither Kubernetes nor Argo rolls the
   pods, and Git no longer says which build runs. Kept as the interim until
   this decision is implemented.
3. **Argo CLI from CI** to sync or restart. Needs an Argo token published to
   SSM, a platform IAM change, and an exception to ADR 0015.
4. **A bot-owned branch.** Argo tracks `deploy`, never `main`. The workflow
   force-pushes `deploy` = `main` + one values commit on merge, and `deploy`
   = branch head + one values commit on the button.

## Decision

Option 4. The platform pointer says `targetRevision: deploy`. `main` keeps
empty image tags and the gitops render fails on an empty tag, so `main`
cannot render by accident. `deploy` is never protected and never edited by
hand; rollback is a force-push of an earlier `deploy` commit.

The merge path triggers on `push` to `main`; the merged pull request and its
labels are recovered from the commit, because a `pull_request: closed` run
would race a second merge for the branch. The button is `workflow_dispatch`
with three checkboxes, `web`, `android`,
`ios`, run against the branch picked in the GitHub UI. `web` is the same
job as the merge path. The two mobile jobs publish tester builds and run in
a `release` Environment that holds the signing secrets.

## Consequences

- No credential beyond the workflow token, no cluster access from CI, and
  ADR 0015 holds.
- The lab has one slot. A button deploy replaces `main`'s deployment until
  the next merge. A second slot is a second pointer in the platform and is
  not built.
- Core 060 req 8 and the `[skip ci]` commit go away; core 030 req 6's
  `release.yml` becomes `deploy.yml`. Both are recorded in `deploy/010`.
- The `deploy` branch is a concept a new contributor must learn: it is
  output, not source.
