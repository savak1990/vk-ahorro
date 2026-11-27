---
id: UC-01
title: Create Account
status: DRAFT
level: user-goal
updated: 2026-09-24
---

# UC-01 — Create Account

**Primary actor:** Shopper
**Secondary actors:** Identity Provider
**Goal:** Get my own Ahorro account in a few taps, so my receipts are kept for me.
**Source:** docs/product/milestones/m1-receipts-and-prices.md §2 "create account"

## Trigger

The Shopper opens Ahorro for the first time and asks to create an account.

## Preconditions

1. The Shopper has no Ahorro account.

## Basic flow

1. The Shopper asks to create an account.
2. The system offers the ways to sign up for this phone (BR-4) and shows the Terms and Conditions and the Privacy Policy, each with a link to its full text.
3. The Shopper accepts the Terms and Conditions and the Privacy Policy.
4. The Shopper chooses Google, or Apple on iOS.
5. The Identity Provider has the Shopper sign in with the chosen provider and returns their verified email address.
6. The system creates the Shopper's profile on the Free tier and signs the Shopper in.
7. The system opens the home and invites the Shopper to submit their latest receipt (UC-06).

## Alternate flows

**A1 — Sign up with email** (from step 4)
1. The Shopper chooses email and enters an email address and a password, with the password rules shown (SR-1).
2. The Identity Provider registers the account and sends a verification code to the email address.
3. The Shopper enters the verification code.
4. The Identity Provider confirms the account.
The flow continues at step 6.

**A2 — Code not received** (from A1 step 3)
1. The Shopper asks for a new code.
2. The Identity Provider sends a new code.
The flow returns to A1 step 3.

**A3 — Email already has an account with another method** (from step 5 or A1 step 2)
1. The system says an account exists for this email and asks the Shopper to sign in with the method they used before.
2. The Shopper signs in with that method (UC-02).
3. The system links the new method to the existing account.
The use case ends with one account that both methods sign in to; no new profile is created.

**E1 — Account already exists with the same method** (from step 5 or A1 step 2)
1. The system says an account exists and offers Sign In (UC-02), or Reset Password (UC-03) for an email account.
The use case ends without a new account.

**E2 — Terms not accepted** (from step 3)
1. The system does not continue until both documents are accepted, and says why.
The use case ends without a new account if the Shopper leaves.

**E3 — Sign-up with the provider cancelled** (from step 5)
1. The Shopper cancels at Google or Apple, or the provider refuses.
The flow returns to step 2.

**E4 — Password too weak** (from A1 step 2)
1. The system names the password rule that is broken (SR-1) and keeps the entered email.
The flow returns to A1 step 1.

**E5 — Wrong or expired code** (from A1 step 4)
1. The system says the code is not valid and offers a new one.
The flow returns to A1 step 3.

## Postconditions

- An account exists at the Identity Provider, verified by Google, by Apple, or by the email code.
- A Shopper profile exists with Tier = Free and a full Receipt Quota.
- The date and version of the accepted Terms and Conditions and Privacy Policy are recorded.
- The Shopper is signed in and sees the home with the invitation to submit their latest receipt.

## Business rules

- **BR-1** Every new Shopper is on the Free tier (M1-BR-1).
- **BR-2** Both the Terms and Conditions and the Privacy Policy must be accepted before an account is created. Acceptance is an explicit action, never pre-selected.
- **BR-3** An email account is usable only after its email address is verified. A Google or Apple account is verified by the provider; no code is sent.
- **BR-4** Sign-up methods: iOS offers Google, Apple and email; Android offers Google and email.
- **BR-5** One account per email address. A second sign-up method for the same email is linked to the existing account, after the Shopper proves they own it by signing in with the existing method.
- **BR-6** An Apple relay address is accepted as the account email. It never matches another account, so BR-5 does not link it.
- **SR-1** Password policy (shared-rules.md), for email accounts only.

## Special requirements

- The app is in Spanish.
- The home invitation reads "Submit Latest Receipt" (Spanish wording to be decided).
- The Privacy Policy states that receipt content is sent to an LLM provider for reading.
- In M1 both documents are stub texts inside the app, each with a version. Later they are published on a web page and the app links to it.

## Acceptance criteria

- **AC-1** (basic) Given a new Shopper, when they accept both documents and sign up with Google, then they are signed in on the Free tier and see the home inviting them to submit their latest receipt.
- **AC-2** (basic) Given a new Shopper on iOS, when they sign up with Apple, then the same result as AC-1.
- **AC-3** (A1) Given a new email address, when the Shopper registers with a valid password and enters the correct code, then the same result as AC-1.
- **AC-4** (A2) Given a pending email registration, when the Shopper asks for a new code, then a new code arrives and it confirms the account.
- **AC-5** (E1) Given an account exists for the email, when the Shopper tries to sign up again, then no second account is created and Sign In is offered.
- **AC-6** (E2) Given only one document accepted, when the Shopper tries to continue, then no account is created.
- **AC-7** (E3) Given the Shopper cancels on the Google screen, when they return, then the sign-up choices are shown again.
- **AC-8** (E4) Given a password that breaks the rules, when the Shopper submits, then the broken rule is named and no account is created.
- **AC-9** (E5) Given a wrong code, when the Shopper enters it, then the account stays unconfirmed and a new code can be requested.
- **AC-10** (basic, record) Given a new account, when its profile is inspected, then it holds the accepted versions and dates of both documents.
- **AC-11** (A3) Given an email account, when the Shopper signs up with Google for the same email and signs in with their email password when asked, then one account exists and both methods sign in to it.
- **AC-12** (basic, platforms) Given Android, when sign-up opens, then Google and email are offered and Apple is not; given iOS, all three are offered.
- **AC-13** (basic, relay) Given Apple hides the email, when the Shopper signs up with Apple, then the account is created with the relay address.

## Open questions

None.
