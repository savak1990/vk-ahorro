# ADR 0011: Deploying and releasing are two workflows, over one shared publish

## Status

Accepted

Narrows ADR 0009 and ADR 0010. Neither is reversed: the pipeline still
deploys to the cluster, and the file that does it is still `deploy.yml`.

## Context

`deploy.yml` carried both channels. It triggered on `push` to `main` and on
`workflow_dispatch`, and the two jobs that differ were gated against each
other on one output:

```yaml
  deploy-dev:
    if: needs.version.outputs.release != 'true'
  tag:
    if: needs.version.outputs.release == 'true'
```

Everything else - `version`, `images`, `charts` - was shared. The `version`
job itself branched on `github.event_name` to decide which arm of
`version.sh` to call and what to set `release` to.

Two problems follow from that shape.

The first is what an operator sees. The Actions sidebar lists one entry,
`deploy`, with a **Run workflow** button. Pressing it cuts a release and tags
the repository. Merging to main deploys to `ahorro-dev`. Those are different
acts with different blast radii, and the UI presents them as one thing with a
checkbox nobody sees until the form opens.

The second is what the file does to anything added later. Every new job has
to declare which channel it belongs to, and the declaration is an `if:` the
reader must evaluate against an output computed three jobs earlier. A skipped
job reports success, so a wrong condition is silent. Mobile artifacts, which
differ per channel in backend, signing environment and retention, would have
doubled that gating.

## Alternatives

**Leave it as one file.** It works, and the gating is correct today. But the
cost is paid by every future reader and every new job, and the Actions UI
cannot be fixed from inside one workflow file.

**Rename `deploy.yml` to `release.yml` and keep one file.** This was raised
because "deploy" seems to describe only half of what the file does. It is the
wrong half to drop: ADR 0010 exists precisely because the pipeline really does
`helm upgrade` into a live namespace on every merge, and that is the common
path. It also resets `github.run_number`, which `deploy/030` uses as the
Android build number, and reverses a rename ADR 0009 made on purpose.

**Duplicate `images` and `charts` into two files.** About 120 lines of
registry logic, including the copy-an-unchanged-image branch, maintained
twice. A divergence between the copies would publish two different things
under one version number, which is the invariant the whole scheme rests on.

## Decision

Three files.

| File | Trigger | Jobs |
|---|---|---|
| `publish.yml` | `workflow_call` | `images`, `charts` |
| `deploy.yml` | `push: [main]` | `version` → `publish` → `deploy-dev` |
| `release.yml` | `workflow_dispatch` | `version` → `publish` → `tag` |

`publish.yml` holds what both channels do identically and takes the version
and the two change flags as inputs. The change flags default to `'false'`,
so a release passes neither: it rebuilds nothing and copies every component.

The two `version` jobs are **not** shared. One calls `version.sh main <sha>`
and runs the paths filter; the other calls `version.sh release <bump>` and
runs no filter. They differ in almost every line, and sharing them would need
a `channel` input that re-creates the branching this ADR removes. Twenty
duplicated lines is the cheaper half of that trade.

Both files declare the **same** concurrency group, `deploy-${{ github.ref }}`
with `cancel-in-progress: false`. They publish to one registry under one
version scheme, so they must queue rather than race.

`deploy.yml` keeps its name and its `deploy-dev` job. The name describes what
this file does that the other does not: it reaches the cluster.

## Consequences

The Actions sidebar now lists `deploy` and `release` as separate entries, and
only `release` has a **Run workflow** button. The thing an operator presses is
named after what it does.

No job needs a channel condition any more. A job's file is its channel. A new
per-channel job is added to one file and is unconditional there, which removes
the class of bug where a mis-written `if:` skips a job and the skip reports
green.

`release.yml` starts its own `github.run_number` at 1. Nothing depended on
that counter when this landed, and `deploy/030` req 6 moves the Android build
number to `git rev-list --count HEAD`, which is identical in both workflows
for the same commit. Had Play already received an upload, this split would
have needed a permanent offset instead.

`deploy/060` req 4 is narrowed rather than reversed: `deploy.yml` still owns
the merge path, and `release.yml` appears beside it. `deploy/060` req 8's
dispatch moves file, unchanged in behaviour.

A nested `workflow_call` does not inherit `permissions`, so each caller grants
`contents: read` and `packages: write` explicitly and `publish.yml` declares
its own. This is more verbose than one file and it is also the reason the
permission each job holds is now readable without tracing a gate.
