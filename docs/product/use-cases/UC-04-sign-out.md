---
id: UC-04
title: Sign Out
status: DRAFT
level: user-goal
updated: 2026-09-23
---

# UC-04 — Sign Out

**Primary actor:** Shopper
**Secondary actors:** Identity Provider
**Goal:** Leave my account on this phone so nobody else using it sees my receipts.
**Source:** docs/product/milestones/m1-receipts-and-prices.md §2 "sign out"

## Trigger

The Shopper asks to sign out.

## Preconditions

1. The Shopper is signed in.

## Basic flow

1. The Shopper asks to sign out.
2. The system tells the Identity Provider to end the session.
3. The system removes the Shopper's receipts, photos and session from this phone.
4. The system shows the sign-in page.

## Alternate flows

**A1 — Receipt still being submitted** (from step 1)
1. The system warns that a receipt is still being processed and asks whether to wait or sign out anyway.
2. The Shopper chooses to sign out anyway; the receipt continues on the server if it was already sent.
The flow returns to step 2.

**E1 — No connection** (from step 2)
1. The system cannot reach the Identity Provider; it still removes local data and the session from this phone.
The flow continues at step 3.

## Postconditions

- Nothing of the Shopper's account remains readable on this phone.
- The Shopper's data on the server is unchanged.

## Business rules

None.

## Special requirements

None.

## Acceptance criteria

- **AC-1** (basic) Given a signed-in Shopper, when they sign out, then the sign-in page shows and reopening the app does not show their receipts.
- **AC-2** (A1) Given a receipt being processed, when the Shopper signs out anyway, then a receipt that already reached the server appears after the next sign-in.
- **AC-3** (E1) Given no connection, when the Shopper signs out, then local data is removed all the same.

## Open questions

None.
