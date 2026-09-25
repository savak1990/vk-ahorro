---
id: "CORE-070"
status: "DRAFT"
updated: "2026-09-21"
---
# 070 — Flutter: trim to the shell

**Status note:** Draft.

**Complexity:** Medium
**Risk:** Low — deletions only; the compiler reports every dangling reference.
**Estimated cost:** ~1 day
**Recommended model:** Sonnet.
**Depends on:** [010-repo-bootstrap](../010-D-repo-bootstrap/spec.md), 090-local-toolchain (to run `flutter analyze`)
**Lifecycle class(es) touched:** None.

## Scope

Remove every concrete screen and domain feature from `flutter-ui/` and keep
the shell: top app bar, bottom tabs (mobile) / navigation rail (web), the
"+" button, theme, adaptive widgets, auth plumbing, logging.

Excludes: runtime configuration and the hello call (080), platform folders
(100).

## Requirements

1. Keep, unchanged unless a deletion forces an edit: `lib/src/screens/templates/app_shell.dart`, `lib/src/config/`, `lib/src/constants/` (delete `platform_colors.dart`, dead), `lib/src/widgets/adaptive/`, `lib/src/widgets/platform_app_bar.dart`, `platform_loading_indicator.dart`, `typography.dart`, `error_state_widget.dart`, `lib/src/services/api_logger.dart`, `operation_id_service.dart`, `lib/src/providers/base_provider.dart`, `amplify_provider.dart`, `lib/src/utils/`.
2. Delete: every file under `lib/src/screens/` except `templates/app_shell.dart` and `main_screen.dart`; every file under `lib/src/widgets/fragments/`; the domain widgets (`add_balance_form`, `*_transaction_form`, `balance_*`, `transaction_*`, `grouped_transactions_sliver`, `monthly_overview_card`, `month_selector`, `category_picker_dialog`, `*_bottom_sheet`, `filter_chips`, `active_*_summary`, `group_items_card`, `settings_*`, `list_item_tile`); every file under `lib/src/models/`; `providers/{balances,categories,transaction_entries,transaction_stats,transactions_filter}_provider.dart`; `services/{api_service,auth_service,openai_agent_service}.dart`; `lib/amplifyconfiguration_prod.dart`; `pipeline/`, `deploy/`, `WIDTH_CONTROL_GUIDE.md`, `test/widget_test.dart`.
3. `pubspec.yaml` MUST drop `syncfusion_flutter_charts`, `lottie`, `shimmer`, `formz`, `flutter_dotenv`, `cached_network_image`, `flutter_svg`, `flutter_staggered_animations`, `intl`, `material_symbols_icons`, `responsive_framework`, and the `.env` asset. `material_symbols_icons` and `responsive_framework` have no importer anywhere in `lib/`, so they drop with the rest. `uuid` MUST stay: the kept `operation_id_service.dart` is its only user, and a hand-written v4 generator is more code than the dependency. Keep `amplify_*`, `provider`, `http`, `flutter_platform_widgets`, `cupertino_icons`, `uuid`.
4. `main_screen.dart` MUST build three `AppShellTab`s — Home, Activity, Account — with placeholder bodies (an icon and the tab name), and one `ActionData('Add', Icons.add, onPressed)` used both as the FAB and as the iOS app bar action, built once by a helper instead of three copies.
5. `app_state_provider.dart` keeps only `amplify`; `main.dart` keeps the Amplify configure, `Authenticator`, `PlatformProvider`/`PlatformTheme`, and a routes map with `/` only. `dotenv.load` is removed.
6. `AccountTab` placeholder MUST keep a sign-out button that calls `AmplifyProvider.signOut()`.
7. One widget test MUST pump `AppShell` with three tabs and a `floatingButtonAction`, tap the FAB, and assert the callback ran.
8. `.github/workflows/ci.yml` MUST gain a `ui` job running `flutter analyze` and `flutter test` on pull requests. 030 created the workflow; these steps belong here because this spec is what makes the Flutter code lint-clean. 090 installs the tool locally, not in CI. A new job is advisory until it is added to `main`'s required-checks list by hand.
9. The root `Makefile` MUST gain `ui-get`, `ui-fix`, `ui-format`, `ui-analyze` and `ui-test`, each a one-line recipe, so CI and a developer run the same command. 100 adds the run and build targets. The first clean-up pass is `ui-get`, then `ui-fix`, then `ui-format`, then `ui-analyze`: `dart fix --apply` resolves most of the rules req 10 enables, so the fix round is mechanical rather than hand-edited.
10. `analysis_options.yaml` MUST enable an explicit lint set on top of `flutter_lints`. The default file switches nothing on, so "`flutter analyze` is clean" would otherwise assert almost nothing. `lib/src/config/theme.dart` MUST be excluded: it is Material Theme Builder output, and regenerating it would undo any fix made there.

## Implementation hints

- Delete first, then let `flutter analyze` list every broken import; fix in `main.dart`, `main_screen.dart`, `app_state_provider.dart`.
- `app_theme.dart`: keep only `materialToCupertino`; delete the `AppTheme` class.
- `flutter pub get` after every `pubspec.yaml` change; commit `pubspec.lock`.

## Testing / acceptance criteria

- `find flutter-ui/lib -name '*.dart' | wc -l` ≤ 35.
- `cd flutter-ui && flutter analyze` → "No issues found"; `flutter test` green.
- `flutter run -d chrome` shows the Authenticator; after sign-in (old pool values still in place at this step) the shell shows three tabs and the "+" button; the Account tab signs out.
- `grep -r "syncfusion\|dotenv\|openai" flutter-ui/lib flutter-ui/pubspec.yaml` returns nothing.
