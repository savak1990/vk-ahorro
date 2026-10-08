# ADR 0009: Three environments, and one version track for the repository

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

1. **A semver per component, hand-bumped in each `Chart.yaml`.** Each
   component's history is its own, and `chart-version-check.sh` keeps
   enforcing the bump. Rejected, after being chosen first and reconsidered:
   the two numbers drift apart, so no single number names what an environment
   runs, the platform pins two values rather than one, and when only one
   component changes something has to remember the other's current version.
   The hand bump is also the step that has already been forgotten once.

1a. **One version track, but publishing only the changed component.** The
   natural reading of "one track", and the worst of both: the numbers still
   drift, so every cost of option 1 survives while the hand bump is the only
   thing removed. Rejected once that was seen.

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

**Option 4, with one version track for the repository.**

`ahorro` holds a released version and is owned by Argo alone. `ahorro-dev`
tracks `main` and `ahorro-pr` holds one release per labeled pull request; both
are owned by the pipeline, which is granted nothing in `ahorro`. The full
shape, the hostnames and the triggers are in `docs/delivery.md`.

One version number names the whole repository and is carried by a git tag.
Every component is published at it on every channel — `-pr-42`, then
`-main.<sha>`, then the clean version at release — and the image tag and the
chart version are the same string, so one number identifies everything an
environment runs. `Chart.yaml`'s `version:` is overridden at package time and
is never hand-edited, which deletes `scripts/chart-version-check.sh`.

**Publishing every component is not rebuilding every component.** One whose
inputs did not change is not built; its manifest is copied to the new tag with
`docker buildx imagetools create`, a registry-side operation that uploads no
layer and takes seconds. Change detection still decides what is built, which
is where the cost is, while every channel carries a complete and coherent set.

The base of a prerelease is the **next** patch version, not the last release.
A prerelease sorts below its release, so a build made after `0.5.0` cannot be
`0.5.0-main.<sha>` — it would claim to predate the release it followed.
`git describe --tags` with the patch bumped gives `0.5.1-main.<sha>`. If the
eventual release is `0.6.0`, the builds before it carry `0.5.1-*`, which is
harmless because nothing pins or range-resolves a prerelease.

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

A chart and an image are republished with identical content under a new
number. `ahorro-web:0.5.0` and `ahorro-web:0.5.1` may be byte-identical. The
cost is cosmetic: GHCR deduplicates the layers, and public packages carry no
storage charge. What is genuinely lost is the ability to read two version
numbers and conclude that one component did not change. The git log answers
that instead.

Mobile becomes simpler rather than harder. `flutter-ui/pubspec.yaml` carries
one version shared by web, Android and iOS, which was awkward against a
per-component scheme and fits a single track exactly. The stores still need
their own build numbers, so `deploy/030` and `deploy/040` stand unchanged.
