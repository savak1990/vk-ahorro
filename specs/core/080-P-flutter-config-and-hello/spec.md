---
id: "CORE-080"
status: "DRAFT"
updated: "2026-09-21"
---
# 080 — Flutter: runtime configuration, Cognito, and the hello call

**Status note:** Draft.

**Complexity:** Medium
**Risk:** Medium — a wrong config path on web breaks the app silently; token handling must send the id token the Go service expects.
**Estimated cost:** ~1 day
**Recommended model:** Sonnet.
**Depends on:** 070-flutter-shell-trim, 055-cognito-and-token, 020-go-hello-service
**Lifecycle class(es) touched:** None.

## Scope

Move every environment value out of source: the app reads its API base
URL and Cognito identifiers at startup (web) or from a build-time define
file (mobile). Then wire the "+" button to `GET /api/v1/hello` and show
the answer.

Excludes: the Cognito pool (the platform's spec AWS-035), the ConfigMap that serves `config.json`
in the cluster (040/060), platform folders (100).

## Requirements

1. `lib/src/config/app_config.dart` MUST expose `AppConfig.load()` returning `apiBaseUrl`, `cognitoUserPoolId`, `cognitoClientId`, `cognitoRegion`. On web it fetches `Uri.base.resolve('config.json')`. On other platforms it reads `String.fromEnvironment` for `API_BASE_URL`, `COGNITO_USER_POOL_ID`, `COGNITO_CLIENT_ID`, `COGNITO_REGION`.
2. The Amplify configuration JSON MUST be built at runtime from `AppConfig` (move the template from `lib/amplifyconfiguration.dart` into a function; delete the hardcoded pool `eu-west-1_iRYFPY5Xv` and client id).
3. When any value is missing, the app MUST show an `ErrorStateWidget` with the missing key names instead of the Authenticator.
4. `flutter-ui/web/config.json` MUST be committed with local defaults: `apiBaseUrl: http://localhost:8080`, empty Cognito values. `flutter-ui/config/*.json` MUST be gitignored; `make ui-config ENV=lab FQDN=<fqdn>` writes `flutter-ui/config/lab.json` from `aws ssm get-parameters-by-path --path /$(PROJECT_NAME)/persistent/ahorro-cognito` (055; there is no `make tf-outputs`, this repository holds no Terraform) and sets `apiBaseUrl` to `https://api-ahorro.<fqdn>`.
5. `lib/src/services/hello_service.dart`: `Future<String> hello()` does `GET $apiBaseUrl/api/v1/hello` with `Authorization: Bearer <id token>` from `Amplify.Auth.fetchAuthSession()` and `X-Request-Id` from `OperationIdService`, logs through `ApiLogger`, and throws a typed error on non-200.
6. The "+" action MUST call `HelloService.hello()` and show the returned message through `MessageUtils.showMessageSafely` (SnackBar on Android and web, Cupertino alert on iOS). Errors show the same way with the status code.
7. Mobile run and build targets MUST pass `--dart-define-from-file=config/$(ENV).json` (100 defines the targets).

## Implementation hints

- `Uri.base.resolve('config.json')` respects `<base href>`; keep `$FLUTTER_BASE_HREF` in `web/index.html`.
- `AppConfig.load()` runs before `runApp` in `main()`; pass the result down with `Provider`.
- The id token is at `(session as CognitoAuthSession).userPoolTokensResult.value.idToken.raw` — the same expression the old `api_service.dart` used.

## Testing / acceptance criteria

- Unit test: `AppConfig.fromJson` with all keys, with a missing key (throws listing the key).
- Unit test: `HelloService.hello()` against a `MockClient` asserts the `Authorization` and `X-Request-Id` headers and parses `message`.
- Web: `make go-run` (auth disabled) + `flutter run -d chrome` with the default `web/config.json` → tap "+" → SnackBar "Hello, anonymous".
- Lab, each platform: sign up and sign in with the Authenticator against the platform's pool, tap "+", see "Hello, <email>"; the Go pod log shows the same `X-Request-Id` the app logged.
- `grep -rn "eu-west-1_\|AppClientId\"" flutter-ui/lib` returns nothing.
