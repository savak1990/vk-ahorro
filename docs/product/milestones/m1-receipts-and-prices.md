# Product M1 — Receipts and prices

**Status:** DRAFT
**Vision:** `docs/product/vision.md`
**Use cases:** `docs/product/use-cases/`
**Research:** `docs/product/research/receipt-reading-and-product-mapping.md`

## 1. Goal

A Shopper in Spain can sign up, photograph a Mercadona or Consum receipt, and within a minute see which of the products they bought cost less elsewhere near them, and how the prices compare with what they paid before.

## 2. In scope

- Account: create account, sign in, reset password, sign out, delete account and all data.
- Postal code: asked for on the Shopper's first Receipt, proposed from the Store address when it has one, and always confirmed by the Shopper; it decides the price areas used.
- Tier: Free only, given at sign-up, 20 receipts per calendar month.
- Receipts: photograph a receipt, read it on the device, extract its lines with an LLM, map lines to products, correct lines, browse receipts, open one receipt.
- Product library: a global grocery library from Open Food Facts (Spain), linked to the chains' own products.
- Prices: a weekly, light collection of Mercadona and Consum online prices, only for price areas that serve Shoppers' postal codes.
- Comparison: per receipt, paid price against current Fresh Prices at both chains and against the Shopper's own earlier prices.
- Analysis: a report across the Shopper's receipts.
- Clients: Android and iOS.

## 3. Out of scope

- Web client for Shopper features.
- Paid tiers, billing, payment provider.
- Notifications and price alerts.
- Shopping lists, basket planning, or price search without a receipt.
- Chains other than Mercadona and Consum.
- Bank connections.
- Receipt input other than a photo (PDF, e-ticket, email).
- Changing the postal code by hand (later milestone).

## 4. Use cases

| ID | Use case | Primary actor |
|---|---|---|
| UC-01 | Create Account | Shopper |
| UC-02 | Sign In | Shopper |
| UC-03 | Reset Password | Shopper |
| UC-04 | Sign Out | Shopper |
| UC-06 | Submit Receipt | Shopper |
| UC-07 | Correct Receipt Lines | Shopper |
| UC-08 | Browse Receipts | Shopper |
| UC-09 | Compare Receipt Prices | Shopper |
| UC-10 | Review Receipt Analysis | Shopper |
| UC-11 | Collect Supermarket Prices | Scheduler |
| UC-12 | Refresh Product Library | Scheduler |
| UC-13 | Delete Account and Data | Shopper |

## 5. Business rules

- **M1-BR-1** Every new Shopper is on the Free tier.
- **M1-BR-2** The Free tier accepts 20 receipts per calendar month. Correcting a receipt does not count.
- **M1-BR-3** A price is a Fresh Price for 14 days after it was observed. Older prices are shown as stale and are not used for "cheaper elsewhere".
- **M1-BR-4** Prices are collected once a week, only for the price areas that serve at least one Shopper's postal code.
- **M1-BR-5** Every price shown states its source (receipt or chain website) and its date.
- **M1-BR-6** Products of different size are compared by Unit Price.

## 6. Non-functional needs

- **Cost.** On-device reading first. The LLM step uses the cheapest Anthropic model that reads receipts well enough; the starting candidate is Claude Haiku 4.5, with Claude Sonnet 5 as the step-up if an evaluation on real receipts shows misses. Expected LLM cost: under one cent per receipt.
- **Latency.** From photo to comparison in under a minute on a normal connection.
- **Privacy.** The Shopper agrees, at sign-up, that receipt content is sent to an LLM provider. Deleting the account deletes receipts, photos, profile and identity.
- **Secrets.** The LLM API key reaches the service as an environment variable from a secret store; it is never committed.
- **Politeness.** Price collection is rate-limited, respects robots.txt, and does not republish chain catalogues.
- **Language.** The app speaks Spanish. English is optional.

## 7. Exit criteria

1. A Shopper on Android and on iOS can go from sign-up to a Price Comparison for a real Mercadona receipt and a real Consum receipt.
2. At least 90% of lines on a set of 20 real receipts are read correctly without correction; the rest can be corrected.
3. At least 80% of read lines map to a Chain Product without correction.
4. The weekly price collection has run successfully for two weeks in a row for every active price area.
5. The 21st receipt in a month is refused with a clear message.
6. Delete Account and Data leaves no receipt, photo, profile or identity behind.

## 8. Risks and actions

- **Chains' conditions of use.** Mercadona and Consum publish a legal notice that may restrict automated extraction; EU and Spanish database rights protect against extracting a substantial part of a database. M1 keeps collection light (M1-BR-4, no republishing). Action: read both legal notices and robots.txt once and record the finding here before the collector runs against production.
- **Receipt reading quality.** Thermal paper, creases and faded print. Mitigation: document-scanner capture, LLM fallback on the photo, and UC-07.
- **Product matching.** Receipts print abbreviated names. Mitigation: match within the chain's own catalogue first, use the paid price as a tie-breaker, and learn Aliases from corrections.
- **Open Food Facts licence.** ODbL requires attribution and share-alike for a published derived database.

## 9. Open questions

- Does a receipt that could not be read at all count against the quota? Proposed: no.
- Consent wording for sending receipt content to the LLM provider; how long Receipt Photos are kept.
- Does ODbL share-alike apply to how Ahorro uses the product library?
- What to show a Shopper whose postal code no chain serves online.
- Architecture follow-ups, stack still open: Postgres now (architecture §11); storage for Receipt Photos; where the weekly jobs run, given the cluster is disposable and prices are persistent; delivery of the LLM key; Spanish UI.
