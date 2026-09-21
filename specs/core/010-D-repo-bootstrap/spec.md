---
id: "CORE-010"
status: "DONE"
updated: "2026-09-21"
---
# 010 — Repository bootstrap and GitHub publication

**Status note:** Done on 2026-09-21. Evidence: `gh repo view savak1990/vk-ahorro
--json visibility,defaultBranchRef` → `PUBLIC` / `main`; both stars return 204;
project "VK Lab" (number 2) lists both repositories; `git log --follow
flutter-ui/pubspec.yaml` reaches 14 old commits, so the 231 renames kept the
history. One deviation: the ignore rules are verified with `git check-ignore`
instead of a Flutter build, because Flutter arrives with spec 090. The star list
was dropped: it lives in the owner's GitHub account, not in this repository.

**Complexity:** Small
**Risk:** Low — a wrong first commit loses rename history for 231 files, which makes the old app hard to consult later.
**Estimated cost:** ~0.5 day
**Recommended model:** Sonnet.
**Depends on:** 000-constitution
**Lifecycle class(es) touched:** None (Git and GitHub only).

## Scope

Turn the working copy into a clean public monorepo: commit the `flutter-ui/`
move, fix ignore rules, rename the branch, publish to GitHub, star it, and
group it with `vk-lab-platform` in one GitHub Project.

Excludes: any code change inside `flutter-ui/` (070), CI workflows (030).

## Requirements

1. The `flutter-ui/` move MUST be its own commit, with no other change, so Git records 231 renames (content is byte-identical to `HEAD`).
2. `.gitignore` MUST match paths under `flutter-ui/` and the new Go, Terraform, and Helm folders. Use unanchored patterns (`**/build/`, `**/.dart_tool/`) and add `flutter-ui/config/*.json`, `.terragrunt-cache/`, `*.tfstate*`, `*.tgz`, `.kube/`.
3. `.metadata` MUST move into `flutter-ui/`, next to `pubspec.yaml`.
4. The default branch MUST be `main`.
5. The repository MUST be public at `github.com/savak1990/vk-ahorro`, with `origin` set over SSH, and the description "Ahorro: Flutter UI + Go services on vk-lab-platform".
6. Both `savak1990/vk-ahorro` and `savak1990/vk-lab-platform` MUST be starred by the owner and linked to one GitHub Project named "VK Lab".

## Implementation hints

- Move commit: `git add -A && git commit -m "Move ahorro-ui into flutter-ui/"`; check with `git show --stat HEAD | grep -c rename`.
- Publish: `gh repo create savak1990/vk-ahorro --public --source=. --remote=origin --push`.
- Star: `gh api -X PUT /user/starred/savak1990/vk-ahorro` (204 on success).
- Project: `gh auth refresh -s project`, then `gh project create --owner savak1990 --title "VK Lab"`, then `gh project link <number> --owner savak1990 --repo savak1990/vk-ahorro` and the same for `vk-lab-platform`.
- A star list is account decoration, not repository state, and GitHub has no API for one. If the owner wants a "VK Lab" list, they create it at `github.com/savak1990?tab=stars` and tick it on both repository pages.

## Testing / acceptance criteria

- `git log --oneline | head -3` shows the move commit and the docs commit above the old history; `git log --follow flutter-ui/pubspec.yaml` reaches the old commits.
- `gh repo view savak1990/vk-ahorro --json visibility,defaultBranchRef` returns `PUBLIC` and `main`.
- `gh api /user/starred/savak1990/vk-ahorro` and `.../vk-lab-platform` return 204.
- `gh project list --owner savak1990` shows "VK Lab"; the project page lists both repositories.
- `git check-ignore -q` succeeds for `flutter-ui/build/x`, `flutter-ui/.dart_tool/x`,
  `flutter-ui/ios/Pods/x`, `flutter-ui/config/lab.json`, `bin/hello`, `dist/a.tgz`,
  `deploy/terraform/live/.terragrunt-cache/x`, and `.kube/c`. The same rules are
  re-checked against a real `flutter build web` under spec 100.
