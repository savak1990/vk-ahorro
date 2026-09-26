---
id: UC-02
title: Sign In
status: DRAFT
level: user-goal
updated: 2026-09-25
---

# UC-02 — Sign In

**Primary actor:** Shopper
**Secondary actors:** Identity Provider
**Goal:** Get back into my account on this phone in a few taps.
**Source:** docs/product/milestones/m1-receipts-and-prices.md §2 "sign in"; architecture §4

## Trigger

The Shopper opens Ahorro while not signed in.

## Preconditions

1. The Shopper has an Ahorro account (UC-01).

## Basic flow

1. The system offers the ways to sign in for this phone (UC-01 BR-4).
2. The Shopper chooses Google, or Apple on iOS.
3. The Identity Provider has the Shopper sign in with the chosen provider and confirms the Shopper's identity.
4. The system signs the Shopper in and opens the home, which invites the Shopper to submit their latest receipt (UC-06), lists their receipts (UC-08), and shows how many receipts are left.

## Alternate flows

**A1 — Sign in with email** (from step 2)
1. The Shopper chooses email and enters their email address and password.
2. The Identity Provider checks them and confirms the Shopper's identity.
The flow continues at step 4.

**A2 — Method not linked yet** (from step 3 or A1 step 2)
1. The chosen method's email belongs to an account created with another method.
2. The system asks the Shopper to sign in with the method they used before.
3. The Shopper signs in with that method, and the system links the new method to the account (UC-01 BR-5).
The flow continues at step 4.

**A3 — No account yet** (from step 3)
1. The Identity Provider confirms the Shopper at Google or Apple, but no Ahorro account exists for that email.
2. The system says there is no account yet and continues with Create Account (UC-01) from its step 3, keeping the chosen provider.
The use case ends; Create Account asks for the Terms and Conditions and the Privacy Policy before any account is created.

**E1 — Wrong email or password** (from A1 step 2)
1. The system says the email or password is wrong, without saying which, and offers Reset Password (UC-03).
The flow returns to A1 step 1.

**E2 — Email not verified** (from A1 step 2)
1. The system offers to send a new verification code and continues as in UC-01 A1 step 3.
The use case ends.

**E3 — Sign-in with the provider cancelled** (from step 3)
1. The Shopper cancels at Google or Apple, or the provider refuses.
The flow returns to step 1.

**E4 — Too many attempts** (from A1 step 2)
1. The Identity Provider blocks further attempts for a while; the system says when to try again.
The use case ends without sign-in.

## Postconditions

- The Shopper is signed in on this phone and stays signed in until Sign Out (UC-04) or the session expires.
- Any newly linked method signs in to the same account from now on.

## Business rules

- **BR-1** A wrong email or password gets one message that does not say which of the two was wrong.
- **BR-2** Signing in never creates an account. A Shopper without an account goes through Create Account, so the Terms and Conditions and the Privacy Policy are always accepted first (UC-01 BR-2).
- **BR-3** Sign-in methods per phone follow UC-01 BR-4; linking follows UC-01 BR-5.

## Special requirements

None.

## Acceptance criteria

- **AC-1** (basic) Given an account created with Google, when the Shopper signs in with Google, then the home shows the invitation to submit the latest receipt, their receipts, and how many receipts are left.
- **AC-2** (basic) Given an account created with Apple, when the Shopper signs in with Apple on iOS, then the same result as AC-1.
- **AC-3** (A1) Given a verified email account, when the Shopper signs in with the right password, then the same result as AC-1.
- **AC-4** (A2) Given an email account, when the Shopper signs in with Google for the same email and then with their email password when asked, then they are signed in and Google signs in to the same account afterwards.
- **AC-5** (A3) Given no account for a Google email, when the Shopper signs in with Google, then no account is created and Create Account asks for the Terms and Conditions and the Privacy Policy.
- **AC-6** (E1) Given a wrong password, when the Shopper signs in, then the same message appears as for an unknown email, and Reset Password is offered.
- **AC-7** (E2) Given an unverified email account, when the Shopper signs in, then a new verification code can be requested.
- **AC-8** (E3) Given the Shopper cancels on the Google screen, when they return, then the sign-in choices are shown again.
- **AC-9** (E4) Given repeated wrong passwords, when the limit is reached, then sign-in is refused and the wait time is shown.
- **AC-10** (basic, platforms) Given Android, when sign-in opens, then Google and email are offered and Apple is not.

## Open questions

- How long a session lasts before the Shopper must sign in again.
- A Shopper who signed up with Apple and a relay address cannot sign in on Android, where Apple is not offered and the relay address has no password. Accept this, add an email password to such accounts, or offer Apple on Android after all?
