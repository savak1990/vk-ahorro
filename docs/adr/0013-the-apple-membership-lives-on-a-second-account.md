# ADR 0013: The Apple membership lives on a second account

## Status

Accepted

Sits beside ADR 0003 rather than narrowing it. That one places AWS identity in
`vk-lab-platform`; this one places an Apple identity with a person, because
Apple sells no other kind.

## Context

`deploy/040` req 0 asked whether the Apple team committed in
`ios/Runner.xcodeproj` was a free Personal Team or a paid Developer Program
membership. Answered on 2026-10-12: free. TestFlight therefore costs $99 a
year, and the question became who pays it.

The operator holds two Apple IDs. Call them A and B, as this ADR does
throughout, because an Apple ID is a personal email address and this
repository is public.

A is signed into the Mac, the iPhone and Xcode. A is also the account that
cannot enroll: Apple's identity check offers one document type, a driver's
license, in both the macOS and the iPhone flow, and A holds none. The
enrollment stops there. B holds an accepted document.

Three facts decided the rest.

An Apple ID signed into a device is independent of the Apple ID that signs a
build. This session proved it on hardware: the app was built under A's team
and installed on an iPhone whose own account played no part, and before any
account existed in Xcode at all the device still paired, appeared in
DeviceHub, and connected over wifi. Nothing in the device relationship reads a
developer account.

An app identifier is globally unique across Apple, not per account.
`com.vkdev1.ahorro` is registered to A's free Personal Team and no other team
can claim it while that registration stands. A free team's registration is
tied to its seven-day profile, so it lapses about a week after the last signed
build. Only a signed build renews it, which means the simulator,
`make ui-build-ios` and CI do not.

CI signs nothing. `build-ios` runs `flutter build ios --release --no-codesign`,
which reads no team and needs no certificate. A fresh `macos-latest` runner has
neither, and the job passes in five and a half minutes.

## Alternatives

**Enroll A anyway, through Apple Developer Support.** Support accepts
alternative documents by hand. Rejected as the primary route because it runs on
Apple's clock with no published duration, and B can enroll today. It stays
available if B's enrollment fails.

**Move everything to B: the Mac, the iPhone, iCloud.** Rejected. It solves a
problem that does not exist. The device relationship never reads the developer
account, so migrating a person's whole digital life to sign an app is cost
without benefit.

**Rename the bundle identifier so B can register it immediately.** Rejected.
`core/100` req 1 pins `com.vkdev1.ahorro` on both platforms, and the Android
`applicationId` already matches it. Changing it to dodge a week of waiting
makes the two platforms disagree for ever.

**Stay on the free team and distribute by hand.** Rejected. A free profile
expires after seven days and is locked to registered devices, so every tester
needs the laptop again every week. That is not distribution.

## Decision

B owns the Apple Developer Program membership, and with it the App Store
Connect record for `com.vkdev1.ahorro`, the App Store Connect API key, the
distribution certificate and the App Store provisioning profile.

A keeps the Mac, the iPhone and their iCloud. Both accounts are signed into
Xcode at once; `Signing & Capabilities` picks which team signs, and that is the
only place the choice is expressed.

`DEVELOPMENT_TEAM` in `flutter-ui/ios/Runner.xcodeproj/project.pbxproj` becomes
B's team id when the membership is active. It is a public identifier and is
committed, as `deploy/040` req 3 already requires.

Until then no signed build runs under A, so A's hold on the identifier lapses
and B can claim it without asking Apple for anything.

## Consequences

- B is responsible for the membership and for the app record, in the ordinary
  sense that they are B's property and B's annual bill. Moving an app between
  Apple accounts afterwards is possible and is not trivial.
- Local iOS work on the physical iPhone pauses until B's membership is active.
  The simulator, the web target and Android are unaffected, and so is every
  check in CI.
- The team id changes twice in the repository's history: once from the previous
  author's imported value to A's, and once from A's to B's. Both changes are
  one line in three places and neither reaches CI.
- If the identifier is still held when B enrolls, the fallback is an Apple
  Developer Support request to release it. A paid account makes that
  conversation easier, because only a paid account has identifier management.
- Nothing here reaches `vk-lab-platform`. An Apple membership is not cluster
  identity, and ADR 0003's boundary is untouched.
