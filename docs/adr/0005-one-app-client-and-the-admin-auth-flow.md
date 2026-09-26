# ADR 0005: One Cognito app client, with the admin password flow

## Status

Accepted

## Context

Spec 050 asked for two app clients on one pool: `vk-ahorro-app` with
`ALLOW_USER_SRP_AUTH` for the Flutter app, and `vk-ahorro-e2e` with
`ALLOW_ADMIN_USER_PASSWORD_AUTH` for the smoke test. Auth flows are configured
per client, not per pool, so a second client is the only way to give the test
path a flow the app client does not have.

The reasoning was sound in general. SRP never sends the password, but it is a
multi-round challenge protocol with no one-line CLI form, so a script cannot
use it. A script needs a flow that takes a username and a password, and least
privilege says keep that flow off the client real users sign in with.

It does not survive this codebase. `internal/platform/auth/jwt.go` holds one
client id and rejects any token whose `aud` (id token) or `client_id` (access
token) differs. The deployed service is configured with the Flutter client's
id, because that is what real users use. A token minted by `vk-ahorro-e2e` is
valid, signed, unexpired — and refused by our own service with a 401. The
second client produces a token that works against nothing.

## Decision

One pool, one client. `vk-ahorro-app` carries `ALLOW_USER_SRP_AUTH`,
`ALLOW_ADMIN_USER_PASSWORD_AUTH` and `ALLOW_REFRESH_TOKEN_AUTH`.
`vk-ahorro-e2e` is not created.

The non-admin `ALLOW_USER_PASSWORD_AUTH` stays off. That is the flow that
matters: anyone holding the public client id can call it, which turns the id
into a password-guessing endpoint.

Adding the admin flow to the app client grants nothing new.
`AdminInitiateAuth` is a signed AWS API call, so it needs credentials in the
account. Anyone holding those could already have called it against any client
in the pool; the split denied them nothing.

`make token` emits the **id token**. A Cognito access token carries no `email`
claim, and the pool uses email as the username attribute, so `username` holds a
UUID — an access token would greet the user by UUID. This also corrects spec
050's acceptance criterion, which required the email greeting from an access
token and could never have passed.

## Consequences

- A scripted token needs AWS credentials. Acceptable: the same operator applies
  the platform's Terraform.
- **MFA cannot be enabled on this pool while the scripted path exists.** With
  `mfa_configuration` set, `AdminInitiateAuth` returns a challenge instead of
  tokens, so `make token` and spec 110's smoke test both stop working. Giving
  real users MFA later is fine, but it needs a different token path for tests.
- Spec 110 loses its `e2e_client_id`; it calls `make token` instead.
- The alternative, kept on the record: widen the verifier to accept a list of
  client ids. Rejected because it changes the authentication path for a test
  convenience. It becomes the right answer if a second genuine audience ever
  appears — a web and a mobile client with different token lifetimes, or a
  machine-to-machine client with a secret.
