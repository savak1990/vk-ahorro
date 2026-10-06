# ADR 0009: Three environments, and a semver per component

## Status

Accepted

Supersedes ADR 0007 together with ADR 0010. Amends constitution §5 and core
specs 030, 040, 060 and 105. Closes out ADR 0006 decisions 4 and 5.

## Context

Nothing in the delivery chain is pinned. `gitops/values.yaml` names the moving
`main` image tag and the wildcard chart version `"*"`. ADR 0006 decision 4
recorded this as an interim and said plainly that it contradicts constitution
§5. Three costs followed, and all three have now been paid.

There is no version to return to. A cluster rebuild runs whatever `main` last
published, so a bad merge cannot be escaped by `make down` and `make up`.

Git does not record what runs. A moving tag leaves the rendered manifest
unchanged, so Argo creates no new pod and reports `Synced` while the cluster
serves an older image. The documented refresh is
`kubectl -n ahorro rollout restart deploy`, run by a human who remembered.

There is nowhere to try a change before merging it. The lab has one slot, so
every change is proved in the place that is also supposed to be stable.

ADR 0007 addressed the first two with a bot-owned `deploy` branch that CI
force-pushes. It was never implemented, and its premise has been rejected: the
operator wants the pipeline to deploy, not to hand off through a commit. ADR
0010 records that half.

## Alternatives

1. **One version for the whole repository.** A release tags `v0.4.0` and both
   charts are packaged at that version. One number to bump in the platform,
   and `chart-version-check.sh` becomes unnecessary. Rejected: a chart that did
   not change still gets a new version, and the operator wants each component's
   history to be its own.

2. **Keep one environment and pin it harder.** Pin exact versions in `ahorro`
   and accept that `main` is only proved after it is released. Rejected: it
   leaves nowhere to validate sign-in against the real user pool before a
   release, which is the check that matters most.

3. **One namespace, two owners.** Argo installs the pinned version into
   `ahorro` and the pipeline upgrades the same release on merge. Rejected on a
   mechanism, not a preference: Argo applies rendered manifests and creates no
   Helm release, so Helm refuses to adopt those objects and the upgrade fails
   with `invalid ownership metadata`. Making it work would need the charts to
   forge Helm's ownership annotations, and a single `make up` would then
   silently undo a merge.

4. **Three environments in three namespaces.**

## Decision

**Option 4, with a semver per component.**

`ahorro` holds a released version and is owned by Argo alone. `ahorro-dev`
tracks `main` and `ahorro-pr` holds one release per labeled pull request; both
are owned by the pipeline, which is granted nothing in `ahorro`. The full
shape, the hostnames and the triggers are in `docs/delivery.md`.

Each component keeps its own semver in its own `Chart.yaml`, bumped by hand.
A build is published on every pull request and every merge, distinguished by a
prerelease suffix — `-pr-42`, then `-main.<sha>`, then the clean version at
release. The image tag and the chart version are the same string, so one
version identifies everything a deployment runs.

GitOps pins an exact version. A range cannot be used even if it were wanted:
Argo resolves versions with `Masterminds/semver`, where a constraint carrying
no prerelease never matches a version that has one, so `"*"` would stop seeing
new builds while still reporting `Synced`.

**`selfHeal` becomes `true`** on both child Applications and on the platform's
pointer. ADR 0006 decision 5 set it to `false` for one stated reason, that the
operator installs those charts by hand and a reconcile would undo it. Hand
work now has `ahorro-dev` and `ahorro-pr` to happen in, so the reason is gone.
This restores core 060 requirement 3, which asked for `true` and which ADR
0006 deviated from.

## Consequences

The existing Argo setup is not rewritten. The child Applications, the pointer,
the AppProject and the golden renders all keep working; this design adds two
namespaces beside them and changes one boolean.

A cluster rebuild restores `ahorro` and leaves the other two empty until the
pipeline runs again. That is intended: `ahorro` is the version to return to.

`kubectl edit` in `ahorro` is reverted within about three minutes. Anything
that needs poking at belongs in `ahorro-dev`.

Two more hostnames and a second copy of both pods. At 10m CPU and 48Mi of
requests per environment that is immaterial against the smallest node pool.

Constitution §5 required GitOps to pin a commit SHA and never a moving tag.
A semver is neither. The clause is amended rather than quietly broken: a SHA
cannot be promoted by a human, and promotion is the behaviour this design
exists to provide. The SHA tag stays on every image as the audit trail.

Mobile is untouched. The scheme extends to it, but `flutter-ui/pubspec.yaml`
carries one version shared by web, Android and iOS, and splitting that is its
own decision.
