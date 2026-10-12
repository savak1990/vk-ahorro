# ADR 0012: A preview is dispatched on a branch, not triggered by a label

## Status

Accepted

Narrows ADR 0009 and ADR 0010. Neither is reversed: a pull request can still
be deployed into `ahorro-pr`, and the pipeline still does it.

## Context

`preview.yml` triggered on five `pull_request` types and deployed when the
pull request carried the `ci:preview-web` label. Adding the label installed,
a push upgraded, removing it uninstalled, and a close uninstalled always.

Three things were wrong with that shape.

The label was the only way in, and it lives in the pull request sidebar, not
where every other deliberate action in this repository lives. A release is a
**Run workflow** button on `release.yml`; a preview was a label. Two triggers
for the same kind of decision.

The workflow ran on every pull request event to conclude, almost always,
"do nothing". Each push to each unlabeled pull request started a `decide` job.

Two more labels, `ci:release-android` and `ci:release-ios`, existed on GitHub
and triggered nothing: a mobile artifact is built on every channel, so no
label decides whether one exists. They only suggested that labels mattered.

The label did carry one real thing. It was the visible record that a pull
request is deployed, so a preview nobody cleaned up could be found.

## Alternatives

**Keep the label.** It works and it was verified. Rejected because the cost
is carried on every pull request to serve the few that are previewed, and
because it leaves two styles of trigger.

**A dispatch that takes a pull request number.** Simple to write. Rejected
because the number is typed by hand, and a wrong one upgrades or removes
somebody else's preview. The branch already names the pull request.

**A comment trigger.** Rejected for the reason spec `deploy/070` already
gives: `issue_comment` fires on every issue and runs the workflow file from
the default branch rather than the pull request head.

## Decision

`preview.yml` triggers on `workflow_dispatch` with one input, `action`, of
`up` or `down`, and on `pull_request: closed`.

A dispatch runs on the pull request's branch. `decide` looks up the open pull
request whose head is that branch and fails when there is none. A close
always tears down, exactly as before.

The `install` job names the GitHub Environment `preview`. That Environment
holds no secret and no protection rule; it exists so the pull request page
shows the branch as deployed, which is the record the label used to be. It
sets no `url`, because the URL embeds the domain.

No label triggers anything. `make repo-settings` removes all three `ci:`
labels and creates the `preview` Environment.

`make preview-ci ACTION=up|down` dispatches the workflow on the current
branch, so the action is reachable without the web page.

## Consequences

A push no longer upgrades a preview. Somebody runs `up` again. That is the
one thing lost, and it is the same trade a release already makes: nothing
moves until it is asked to.

The workflow no longer runs on pushes at all, so an unpreviewed pull request
costs one `decide` job, at its close.

Teardown on close is unchanged, so a merged or abandoned pull request still
leaves no release and no DNS record behind.

The Environment marks a branch deployed when `install` succeeds, and
`install` ends green with a warning when the cluster is unreachable. A
deployed mark therefore means "published and attempted", and the run summary
says which. Nothing marks the deployment inactive after `down`; GitHub shows
the last deployment, and the comment on the pull request says how to check.

The **Run workflow** button appears only once this file is on the default
branch. Before that, the workflow is dispatched with `gh workflow run
--ref <branch>`, which is what `make preview-ci` does.

The trust policy of the CI role accepts every subject of this repository, so
neither the dispatch nor the new Environment needs a platform change.
