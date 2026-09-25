---
id: UC-06
title: Submit Receipt
status: DRAFT
level: user-goal
updated: 2026-09-25
---

# UC-06 — Submit Receipt

**Primary actor:** Shopper
**Secondary actors:** LLM Receipt Parser
**Goal:** Turn my paper receipt into data Ahorro can compare, with one photo.
**Source:** vision §3 steps 1–3; docs/product/milestones/m1-receipts-and-prices.md §2 "receipts"

## Trigger

The Shopper asks to add a receipt.

## Preconditions

1. The Shopper is signed in.

## Basic flow

1. The Shopper asks to add a receipt.
2. The system shows how many receipts are left this month and opens the camera in document mode.
3. The Shopper photographs the whole receipt.
4. The system crops the Receipt Photo and produces a Receipt Reading on the phone.
5. The system sends the Receipt Reading to the LLM Receipt Parser.
6. The LLM Receipt Parser returns the Chain, Store, date, total and Receipt Lines.
7. The system checks that the Receipt Lines add up to the total and maps each Receipt Line to a Chain Product.
8. The system shows the Receipt: Chain, Store, date, total, each Receipt Line with its matched product, and marks lines it is unsure about.
9. The Shopper confirms the Receipt.
10. The system records the Receipt and counts it against the Receipt Quota.
11. If the Shopper has no postal code yet, the system proposes the postal code of the Store's address and asks the Shopper to confirm it as their usual postal code.
12. The Shopper confirms, and the system saves it as the Shopper's default postal code.
13. The system opens Compare Receipt Prices (UC-09).

## Alternate flows

**A1 — Reading too weak on the phone** (from step 5)
1. The system sends the Receipt Photo instead of the Receipt Reading.
2. The LLM Receipt Parser reads the photo.
The flow continues at step 6.

**A2 — Lines do not add up** (from step 7)
1. The system sends the Receipt Photo to the LLM Receipt Parser for a second reading.
2. If the new reading adds up, the flow continues at step 7; if not, the system continues at step 8 and marks the Receipt as not adding up.

**A3 — Long receipt** (from step 3)
1. The Shopper photographs the receipt in two or more parts.
2. The system joins the parts into one Receipt Photo.
The flow continues at step 4.

**A4 — Shopper fixes lines now** (from step 9)
1. The Shopper chooses to correct lines; the system continues with Correct Receipt Lines (UC-07).
The flow returns to step 9.

**A5 — Store address has no postal code** (from step 11)
1. The system cannot find a postal code in the Store's address and asks the Shopper to enter their usual postal code.
2. The Shopper enters it.
The flow continues at step 12.

**A6 — Proposed postal code is not the usual one** (from step 11)
1. The Shopper chooses to change it and enters their usual postal code.
The flow continues at step 12.

**A7 — Shopper already has a postal code** (from step 11)
1. The system does not ask again.
The flow continues at step 13.

**A8 — Shopper skips the postal code** (from step 11 or A5 step 1)
1. The Shopper skips.
2. The system saves no postal code and will ask again with the Shopper's next confirmed Receipt.
The flow continues at step 13.

**A9 — Use my location** (from step 11, A5 step 1 or A6 step 1)
1. The Shopper chooses to use their location instead of typing.
2. The system explains in one sentence that the location is used only to suggest a postal code, and asks for location access.
3. The Shopper allows location access.
4. The system finds the postal code of the current location and proposes it.
The flow continues at step 12.

**E1 — Quota reached** (from step 2)
1. The system says the 20 receipts for this month are used and when the count resets.
The use case ends without a new Receipt.

**E2 — Unreadable or not a receipt** (from step 6)
1. The system says the photo could not be read as a receipt and offers to take another.
The flow returns to step 3; nothing counts against the quota.

**E3 — Chain not supported** (from step 6)
1. The system says only Mercadona and Consum receipts are supported for now.
The use case ends without a new Receipt; nothing counts against the quota.

**E4 — Duplicate receipt** (from step 7)
1. The system finds a Receipt with the same Chain, Store, date, time and total, and opens it instead.
The use case ends without a new Receipt; nothing counts against the quota.

**E5 — No connection** (from step 5)
1. The system keeps the Receipt Photo and Receipt Reading on the phone and sends them when the connection returns.
The use case ends; the Receipt appears when processing finishes.
**E6 — Not a Spanish postal code** (from A5 step 2 or A6 step 1)
1. The system says the postal code is not valid.
The Shopper enters it again.

**E7 — Location refused, not found, or outside Spain** (from A9 step 3 or A9 step 4)
1. The system says it could not suggest a postal code from the location and asks the Shopper to type it.
The flow continues at A5 step 2.

## Postconditions

- A Receipt exists with Chain, Store, date, total and Receipt Lines, each line linked to a Chain Product or marked unmatched.
- Every matched Receipt Line is also a Price Observation with source "receipt" and the receipt date.
- The Receipt Quota for this month is one lower.
- The Shopper has a default postal code that they confirmed or entered, or none if they skipped.

## Business rules

- **BR-1** Free tier: 20 Receipts per calendar month (M1-BR-2). Only confirmed Receipts count.
- **BR-2** Only Mercadona and Consum receipts are accepted in M1.
- **BR-3** Reading happens on the phone first; the Receipt Photo leaves the phone only when the reading is too weak or does not add up.
- **BR-4** Matching looks first at Aliases, then at the Chain's catalogue for the Price Area of the Receipt's Store, using the paid price as a tie-breaker.
- **BR-5** While the Shopper has no postal code, the system asks for it after every confirmed Receipt: proposed from the Store's address when it has one, typed by the Shopper otherwise, and always confirmed by the Shopper. Once set, Receipts never change it.
- **BR-6** A postal code is valid when it is five digits and exists in Spain.
- **BR-7** Location is read only when the Shopper chooses to use it, once, never in the background. Only the confirmed postal code is stored, never the location.

## Special requirements

- From photo to the Receipt shown in step 8 in under 30 seconds on a normal connection.
- Receipt Photos are kept only as long as the retention rule allows.

## Acceptance criteria

- **AC-1** (basic) Given 20 receipts left and a clear Mercadona receipt, when the Shopper photographs and confirms it, then the Receipt shows with lines and matches, 19 receipts are left, and Compare Receipt Prices opens.
- **AC-2** (A1) Given a faded receipt, when the phone reading is too weak, then the photo is read by the LLM Receipt Parser and the Receipt is shown.
- **AC-3** (A2) Given a reading whose lines do not add up after a second reading, when shown, then the Receipt is marked as not adding up.
- **AC-4** (A3) Given a receipt taken in two parts, when joined, then all lines appear once.
- **AC-5** (A4) Given a shown Receipt, when the Shopper corrects a line before confirming, then the confirmed Receipt holds the correction.
- **AC-6** (E1) Given 0 receipts left, when the Shopper asks to add a receipt, then the camera does not open and the reset date is shown.
- **AC-7** (E2) Given a photo of a menu, when submitted, then it is refused and the quota is unchanged.
- **AC-8** (E3) Given a receipt from another chain, when submitted, then it is refused and the quota is unchanged.
- **AC-9** (E4) Given a Receipt already submitted, when the same receipt is photographed again, then the existing Receipt opens and the quota is unchanged.
- **AC-10** (E5) Given no connection, when a receipt is photographed, then it is processed after the connection returns.
- **AC-11** (A5) Given a first Receipt whose Store address has no postal code, when confirmed, then the Shopper is asked to enter their postal code, and the entered one is saved.
- **AC-12** (basic, postal code) Given a Shopper with no postal code, when their first Mercadona Receipt from a store in Valencia is confirmed, then that store's postal code is proposed, and it becomes their default only after they confirm it.
- **AC-13** (A6) Given a proposed postal code, when the Shopper enters a different valid one, then the entered one is saved.
- **AC-14** (A7) Given a Shopper with a postal code, when a Receipt from another area is confirmed, then they are not asked and their postal code is unchanged.
- **AC-15** (E6) Given "1234", when entered as the postal code, then it is refused as not valid.
- **AC-16** (A8) Given a Shopper who skipped the postal code, when their next Receipt is confirmed, then they are asked for it again.
- **AC-17** (A9) Given a first Receipt whose Store address has no postal code, when the Shopper chooses to use their location and allows access, then the postal code of their location is proposed and saved after they confirm it.
- **AC-18** (E7) Given the Shopper refuses location access, when asked, then they can type the postal code instead.
- **AC-19** (A9, privacy) Given a postal code found from the location, when the stored profile is inspected, then no location coordinates are found.

## Open questions

- Retention period for Receipt Photos on the server, if they are kept at all.
- Is the quota counted per calendar month in Spanish time?
