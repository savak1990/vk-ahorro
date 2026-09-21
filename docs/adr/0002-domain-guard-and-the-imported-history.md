# ADR 0002: The domain guard, and the history it cannot clean

## Status

Accepted

## Context

Constitution requirement 4 says no root domain is ever committed. Nothing
enforced it, so the first run of the new guard found the root domain in
`flutter-ui/lib/src/config/app_config.dart`, as the default value of the API
base URL. It had been there since the Flutter app's own first commits in June
2025, and reached this repository with the milestone-0 import. It is present
in 158 of the 188 commits, and this repository is public.

Three ways out were considered:

1. Clean the working tree and keep the history.
2. Rewrite every commit with `git filter-repo`, then force-push.
3. Rewrite, delete the repository, and push the clean history to a new one.

Option 2 does not finish the job on its own: GitHub serves the replaced
commits by SHA until its garbage collection runs. Option 3 does, at the cost
of the pull request, the stars and the project link that spec 010 records as
done. Both are loud, and the value is a domain the owner controls, which
Certificate Transparency already publishes for any subdomain that ever held a
public certificate.

## Decision

Take option 1. Remove the value from the working tree and record a baseline.

`scripts/domain-guard-baseline` holds one commit id. The guard scans the
working tree always, and scans commits only where they are **not** reachable
from that baseline. History up to the baseline is the imported, pre-
constitution past: known to carry the value, out of scope, and deliberately
not rewritten. Every commit after it is in scope, and a new occurrence fails
CI.

The guard reports file names and commit ids, never a matched line, because
this repository is public. The pattern reaches `git grep` through a temporary
file, so it is never visible in a process listing.

## Consequences

- The value stays readable in this repository's history. That is accepted,
  recorded here, and not a licence to add it again.
- Moving the baseline forward is a deliberate act. It hides commits from the
  guard, so it belongs in a commit of its own with a reason.
- A later decision to rewrite the history supersedes this ADR. The baseline
  file is then the first thing to delete.
