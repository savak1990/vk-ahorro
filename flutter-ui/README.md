# flutter-ui

The Ahorro client: one Flutter app for Android, iOS and web.

At this point the app is the navigation shell only — three tabs (Home,
Activity, Account), an adaptive "+" action, the theme, and Cognito sign-in
through the Amplify Authenticator. The tab bodies are placeholders. Spec 080
wires the "+" button to the hello service.

## Layout

| Path | Holds |
|---|---|
| `lib/main.dart` | Entry point: Amplify configure, `Authenticator`, theme, routes |
| `lib/src/screens/templates/app_shell.dart` | Navigation rail on web, bottom bar and FAB on mobile |
| `lib/src/screens/main_screen.dart` | The three tabs and the "+" action |
| `lib/src/widgets/adaptive/` | Platform-neutral button, dropdown, segmented control |
| `lib/src/providers/` | `provider` + `ChangeNotifier` state |
| `lib/src/services/` | Request logging and operation ids |

## Running it

Every entry point is a `make` target in the repository root, not a command
run from this folder. `make help` lists them all.

```
make ui-get          # fetch dependencies
make ui-analyze      # lint
make ui-test         # widget tests
make ui-run-web      # Chrome on :3000
make ui-run-android  # the ahorro emulator
make ui-run-ios      # an iPhone simulator
```

`make ui-run-web` expects the API on `:8080`, which `make go-run` provides.

Spec 090 installs the toolchain these targets need.
