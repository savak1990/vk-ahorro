---
id: UC-03
title: Reset Password
status: DRAFT
level: user-goal
updated: 2026-09-24
---

# UC-03 — Reset Password

**Primary actor:** Shopper
**Secondary actors:** Identity Provider
**Goal:** Regain access to my account when I forgot my password.
**Source:** docs/product/milestones/m1-receipts-and-prices.md §2 "reset password"

## Trigger

The Shopper asks to reset their password, usually from Sign In.

## Preconditions

None.

## Basic flow

1. The Shopper enters their email address.
2. The system asks the Identity Provider to start a reset.
3. The Identity Provider sends a reset code to the email address.
4. The system says a reset code was sent to the email address.
5. The Shopper enters the code and a new password, with the password rules shown (SR-1).
6. The Identity Provider confirms the new password.
7. The system signs the Shopper in and opens their receipts.

## Alternate flows

**A1 — No account for the email** (from step 3)
1. The Identity Provider reports that no account exists for the email address.
2. The system says there is no account for this email and offers Create Account (UC-01), with the email address already filled in.
The use case ends without a reset; if the Shopper accepts, Create Account starts.

**A2 — Account uses Google or Apple** (from step 3)
1. The system says this account signs in with Google or Apple and has no Ahorro password, and offers Sign In (UC-02) with that provider.
The use case ends without a reset.

**E1 — Wrong or expired code** (from step 6)
1. The system says the code is not valid and offers a new one.
The flow returns to step 5.

**E2 — Password too weak** (from step 6)
1. The system names the password rule that is broken (SR-1).
The flow returns to step 5.

**E3 — Same as the current password** (from step 6)
1. The Identity Provider refuses a new password that matches the current one.
2. The system says the new password must differ from the current one.
The flow returns to step 5.

## Postconditions

- The old password no longer works; the new one does.
- The Shopper is signed in on this phone.

## Business rules

- **BR-1** Reset Password tells the Shopper when no account exists for the email, as Create Account (UC-01 E1) already tells them when one does.
- **BR-2** The new password must differ from the current password. Only the Identity Provider can check this, because the system never holds the password.
- **SR-1** Password policy (shared-rules.md).

## Special requirements

None.

## Acceptance criteria

- **AC-1** (basic) Given an account, when the Shopper enters the correct code and a valid new password, then they are signed in and the old password is refused afterwards.
- **AC-2** (A1) Given an email without an account, when a reset is requested, then no email is sent, the Shopper is told there is no account, and Create Account opens with the email filled in when they accept.
- **AC-3** (E1) Given an expired code, when the Shopper enters it, then the password is unchanged and a new code can be requested.
- **AC-4** (E2) Given a weak new password, when submitted, then the broken rule is named and the password is unchanged.
- **AC-5** (E3) Given the current password entered as the new one, when submitted, then it is refused with the must-differ message and the password is unchanged.
- **AC-6** (A2) Given an account created with Apple, when a reset is requested for its email, then no code is sent and Sign In with Apple is offered.

## Open questions

- Does the Identity Provider support refusing a reused password on the plan Ahorro uses, and at what cost? If not, BR-2 needs another approach or is dropped.
- Only the current password, or also the last few? Proposed: only the current one.
