---
id: "CORE-120"
status: "DRAFT"
updated: "2026-09-25"
---
# 120 — Imported app cleanup

**Status note:** Draft. Most of it landed with 070 and 100; this spec records
what those two do not own and tracks the one open decision.

**Complexity:** Small
**Risk:** Low — metadata and naming only; no behavior changes.
**Estimated cost:** ~2 hours
**Recommended model:** Sonnet.
**Depends on:** [070-flutter-shell-trim](../070-D-flutter-shell-trim/spec.md), [100-flutter-platforms](../100-P-flutter-platforms/spec.md)
**Lifecycle class(es) touched:** None.

## Scope

`flutter-ui/` arrived as a copy of a previous personal-finance project. 070
removes the domain code and 100 fixes the platform identity. This spec covers
the leftovers of the copy that neither of them names: package metadata, the
lint configuration, the generated project files, and the comment language.

Excludes: the Dart code the shell needs (070), application and bundle ids
(100), runtime configuration (080).

## Requirements

1. `pubspec.yaml` `description` MUST NOT be the `flutter create` placeholder
   "A new Flutter project.". The package `name` stays `ahorro_ui`, because
   renaming it rewrites every `package:` import for no gain.
2. `flutter-ui/README.md` MUST describe this app: what the shell contains and
   which `make` target runs it. The `flutter create` boilerplate MUST go.
3. `analysis_options.yaml` MUST enable an explicit lint set on top of
   `flutter_lints`, so `flutter analyze` asserts something. 070 req 10 states
   the same rule; this spec records the chosen rules.
4. `flutter-ui/.metadata` `migration.platforms` MUST list only the three
   platforms this repository targets, after 100 req 5 deletes the other folders.
5. Every source file MUST be ASCII. The imported code carried Russian section
   labels through `lib/`. An ASCII rule is checkable in one grep and does not
   depend on naming which languages are unwelcome.
6. `web/index.html` and `web/manifest.json` MUST NOT carry the placeholder
   description "A new Flutter project.". 100 req 1 covers the titles only.
7. The Dart sources MUST carry no comments at all at this point. The shell is
   short enough to read directly, and the imported comments restated what the
   next line already said. A comment is earned later, when something is not
   obvious from the code; the constitution caps it at three lines.
8. The generated platform files MUST drop the `flutter create` template
   comments and its two `TODO` markers. Two comments stay because they carry
   information the file does not: the `flutterEmbedding` meta-data warning in
   `AndroidManifest.xml` and the base-href note in `web/index.html`, which 080
   depends on.

## Open decision

`lib/src/widgets/platform_app_bar.dart` declares a `PlatformAppBar` that
collides by name with the one `flutter_platform_widgets` exports, which is the
one `app_shell.dart` actually uses. Either delete the local widget or rename
it. Nothing imports it today, so this is not urgent; it is recorded so the
collision does not surprise the next person who writes `PlatformAppBar`.

The same question applies to `platform_loading_indicator.dart` and to the
overlap between `lib/src/widgets/typography.dart` and
`lib/src/constants/app_typography.dart`. `error_state_widget.dart` is exempt:
080 req 3 needs it.

## Implementation hints

- The lint set is a judgement call, not a copy of `flutter_lints` with
  everything on. A rule that produces noise the team then ignores is worse
  than no rule.
- `grep -rnP "[^\x00-\x7F]" flutter-ui/lib` finds any non-ASCII character,
  which is a stronger check than searching for one alphabet.

## Testing / acceptance criteria

- `grep -rn "A new Flutter project" flutter-ui` returns nothing.
- `grep -rnP "[^\x00-\x7F]" flutter-ui/lib flutter-ui/test` returns nothing.
- `grep -rn "//\|/\*" flutter-ui/lib flutter-ui/test --include='*.dart'`
  returns nothing.
- `grep -c "platform:" flutter-ui/.metadata` returns 4 (root, android, ios, web).
- `analysis_options.yaml` lists rules under `linter: rules:`.
- `make ui-analyze` stays clean after the rules are enabled.
