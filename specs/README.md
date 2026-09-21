# Specs

Specs are the requirements for this repository. Each spec is a folder with a
`spec.md`. The format copies `vk-lab-platform/specs/` so both repositories
read the same way.

| Folder | Holds | `id` prefix |
|---|---|---|
| `core/` | The first milestone: hello-world service, Flutter shell, Cognito, GitOps | `CORE-` |

## Folder name

`NNN-X-name`, for example `core/020-P-go-hello-service`.

- `NNN` and the front-matter `id` are the stable identifiers. Never renumber
  them. Numbers step by ten; insert new specs into the gaps.
- `X` is the status letter. When `status:` changes, rename the folder in the
  same commit and update links to it.

## Status letters

| Letter | Meaning | `status:` values |
|---|---|---|
| `D` | done | `DONE` |
| `A` | active | `IN_PROGRESS`, `IN_REVIEW` |
| `P` | planned | `DRAFT`, `READY`, `BLOCKED` |
| `Z` | closed, not done | `DEFERRED`, `SUPERSEDED`, `CANCELLED` |

The front-matter `status:` is the source of truth; the letter is a coarse
view of it.

## Body format

Front matter (`id`, `status`, `updated`), then:

1. `# NNN — Title`
2. `**Status note:**` and the bold-label block (Complexity, Risk, Estimated
   cost, Recommended model, Depends on, Lifecycle class(es) touched)
3. `## Scope` with an explicit `Excludes:` paragraph
4. `## Requirements` — numbered, MUST / MUST NOT, each citing the
   constitution or a sibling spec where a rule comes from
5. `## Implementation hints`
6. `## Testing / acceptance criteria` — observable checks, not tasks

## Order of work

Implement `core/` specs in numeric order. Each spec depends on the ones it
lists under **Depends on**.
