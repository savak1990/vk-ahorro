---
id: UC-05
title: Set Up Profile
status: RETIRED
level: user-goal
updated: 2026-09-24
---

# UC-05 — Set Up Profile

**Retired:** 2026-09-24 — Ahorro no longer asks for a postal code at sign-up. The default postal code comes from the Store address on the Shopper's first Receipt (UC-06). Letting the Shopper change it is planned for a later milestone.

**Primary actor:** Shopper
**Secondary actors:** None
**Goal:** Give Ahorro my usual postal code with as little effort as possible.
**Source:** docs/product/milestones/m1-receipts-and-prices.md §2 "postal code, which decides the price areas used"

## Trigger

The Shopper finishes Create Account (UC-01), or signs in without a postal code (UC-02 A1).

## Preconditions

1. The Shopper is signed in.

## Basic flow

1. The system explains in one sentence that the location is used only to find the Shopper's postal code, and asks for location access.
2. The Shopper allows location access.
3. The system finds the postal code of the Shopper's current location.
4. The system shows the postal code and asks the Shopper to confirm it as their usual one.
5. The Shopper confirms.
6. The system saves the postal code as the Shopper's default and opens Submit Receipt (UC-06).

## Alternate flows

**A1 — Not the usual postal code** (from step 4)
1. The Shopper chooses to change it and enters their usual postal code.
The flow continues at step 6.

**A2 — Location access refused** (from step 2)
1. The system asks the Shopper to type their postal code.
2. The Shopper enters it.
The flow continues at step 6.

**A3 — Skip for now** (from step 1 or step 4)
1. The Shopper skips.
2. The system opens Submit Receipt (UC-06) without a postal code and asks again the next time the postal code is needed.
The use case ends without a default postal code.

**A4 — Change later** (trigger: from the profile)
1. The system shows the current postal code and offers to detect it again or type a new one.
The flow continues at step 1 or at A2 step 2.

**E1 — Location not found or outside Spain** (from step 3)
1. The system says it could not find a Spanish postal code for this location.
The flow continues at A2.

**E2 — Not a Spanish postal code** (from A1 or A2)
1. The system says the postal code is not valid.
The Shopper enters it again.

## Postconditions

- The Shopper's profile holds a default Spanish postal code, or none if skipped.
- The location itself is not stored; only the postal code is.

## Business rules

- **BR-1** One default postal code per Shopper.
- **BR-2** Location is read once, only while this use case runs, never in the background.
- **BR-3** A postal code is valid when it is five digits and exists in Spain.

## Special requirements

- The happy path is two taps after sign-up: allow location, confirm.
- The postal code is personal data; it is deleted with the account (UC-13).

## Acceptance criteria

- **AC-1** (basic) Given a new Shopper in Valencia, when they allow location and confirm, then their profile holds the detected postal code and Submit Receipt opens.
- **AC-2** (A1) Given a detected postal code that is not their usual one, when the Shopper types another valid one, then the typed one is saved.
- **AC-3** (A2) Given the Shopper refuses location access, when they type a valid postal code, then it is saved.
- **AC-4** (A3) Given the Shopper skips, when they later need a postal code, then they are asked again.
- **AC-5** (A4) Given a saved postal code, when the Shopper detects again from the profile, then the new confirmed postal code replaces it.
- **AC-6** (E1) Given the phone is outside Spain, when location is read, then the Shopper is asked to type a postal code.
- **AC-7** (E2) Given "1234", when typed, then it is refused as not valid.
- **AC-8** (basic, privacy) Given a saved postal code, when the stored profile is inspected, then no coordinates are found.

## Open questions

- Which feature first needs the postal code, now that Milestone 1 of the vision has no prices? Decides when A3 asks again.
- Rename to "Set Default Postal Code", since the profile holds nothing else in M1?
