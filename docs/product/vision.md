# Ahorro — Product vision

Ahorro helps a shopper in Spain spend less on groceries. This document holds
the product goal, the user flows, and the plan by milestone. It is the source
for the feature specs in `specs/`. `docs/architecture.md` covers the platform.
This document covers the product.

## 1. What it does

A shopper takes a photo of a grocery receipt. The app reads the receipt and
saves the basket. Later, the app shows where the same basket costs less, item
by item. Over time, the app also tells the shopper where to shop next.

Two rules guide every feature:

1. Show the saving per item, never one black-box number. The shopper must
   trust it.
2. Start useful on day 1, even before price data exists.

The first market is Valencia, Spain.

## 2. Milestones

The product grows in milestones. Each milestone is a set of features that ship
together. Specs live in a folder per milestone (see section 10).

### Milestone 1 — no prices yet

Goal: a useful app that is easy to promote, before price data exists.

- Photo of a receipt, then parsed lines, then the shopper corrects them, then
  saved history.
- When there is no price to compare, show "no price data yet", not an error.
- On-demand list: the shopper presses "I am going shopping" and gets a list to
  buy.
- Free to use. A free app is easier to promote and brings early users.

### Milestone 2 — prices

Goal: add the main draw — "you could pay less here".

- Compare the basket across chains. Show the saving per item.
- Split-basket advice: buy most items here, these three there, save €X.
- A paid Pro tier starts here (see section 5).

### Later milestones

- Predict the list from shopping cadence. Send it on a schedule with a push.
- Suggest a similar product when a chain lacks the exact item. This is far in
  the future and needs a recommender.
- Automation, such as placing an order in Mercadona.

## 3. Flow A — check a receipt (reactive)

This is the hook. The shopper acts, the app answers.

1. Take a photo of the receipt after shopping.
2. The app reads the store, the date, and the lines (name, quantity, unit
   price, total).
3. The app checks the parse and asks the shopper to fix problems before save.
   Two basic checks: the total does not match the sum of the lines, and
   unclear lines.
4. Milestone 1: save the basket to history. Milestone 2: compare it across
   chains and show the saving per item.

Why it works: the shopper gets value from a purchase already made. No change
of habit is needed to try it.

## 4. Flow B — shopping list and where to buy (proactive)

This keeps users coming back. The app helps before the next trip.

1. The shopper presses "I am going shopping".
2. The app builds a list from past baskets, or the shopper edits one.
3. Milestone 1 (free): collect the list of items to buy. That already helps.
4. Milestone 2 (paid): add prices, split the list by supermarket, and show the
   total saving.

Order of delivery: on-demand first. Scheduled and predictive lists come later.

## 5. Money

The product keeps the notion of tiers. It starts with one tier and adds more
later. A receipt check means one run of Flow A on one receipt.

- Start with a single "free for all" tier. A free app is easier to promote and
  to grow.
- Cap the free tier at 20 receipt checks per user. Each check costs compute, so
  the cap controls cost. Revise the number later.
- Keep analytics free in general. Gate only specific features.
- Add a paid Pro tier with milestone 2: prices, split-basket savings, and later
  automation.
- Option for later: add more tiers, or tighten free access once the paid value
  is strong.

## 6. Receipt cases to handle

Some receipts are hard. Define the exact rules in a dedicated parsing module,
not here.

- A long receipt may need more than one photo.
- A receipt may come from a shop that is not a main chain.
- A photo may be low quality or hard to read.

Rule for all of them: parse what is clear, flag the rest, and let the shopper
fix it.

## 7. Product matching

Match a receipt line to a real product in this order:

1. Retailer catalog. It uses the same names as the receipt, so this match is
   easy.
2. Open Food Facts. This is a free catalog indexed by barcode. Use it as the
   shared product dictionary across chains.
3. For a store brand with no cross-chain barcode, match by name, category, and
   size with an LLM.

Open Food Facts is weak on store brands. That is why the retailer catalog
comes first.

## 8. Price data sources

Use the cheapest source that covers a chain:

1. A business feed from an existing comparator. This is best for Mercadona,
   which has no easy public catalog.
2. Ready-made scrapers, for early tests of the matching logic.
3. Own scrapers, only where the first two cost too much or miss a chain.

Start milestone 2 with three or four chains that have accessible prices, such
as Carrefour, Alcampo, Consum, and DIA.

## 9. Analytics modules

The analytics splits into small modules. Each module has a fixed input and
output. A module can start as a stub and improve later, without a change to
the others. Test each module on fixture data.

| Module | Job | In → Out |
|---|---|---|
| M1 Receipt Ingestion | Photo to structured receipt | image → { store, date, lines } |
| M2 Product Normalization | Line to canonical product | raw line → { canonical_id, confidence } or no_match |
| M3 Price Index | Prices per store | canonical_id → { store → price, as_of } |
| M4 Basket Comparison | Recompute basket elsewhere | basket + M3 → per-store total, per-item delta |
| M5 Shopping Profile | History to habits | baskets → recurring items, cadence, spend |
| M6 List & Recommender | Predict list, pick stores | profile + M3/M4 → ranked stores, split plan |
| M7 Savings Ledger | Track savings over time | comparisons → trend, lifetime savings |
| M8 Entitlements | Caps and paid features | user → photo cap, unlocked features |

Flow A uses M1, then M2, then M3, then M4. It logs to M7. M8 sets the caps.
Flow B uses M5, then M6, with M3 and M4. M8 sets the caps.

Pass confidence through the flow. A no_match line or a low-confidence line
shows as "no comparison available".

## 10. From vision to specs

A spec is one small feature that a person can plan, build, and test. This
document is not a spec.

The path from here:

1. A product agent reads this document and `docs/architecture.md`.
2. It writes one spec per feature into a milestone folder, for example
   `specs/product/milestone1/`.
3. Each spec names the section it delivers.

## 11. Open questions

- Photo caps: the exact free and paid numbers.
- The confidence threshold to show or hide a comparison.
- The "similar product" rule: same category and size, or tighter.
- The storage engine for prices and products. The prior sketch named
  ClickHouse or BigQuery. This repo runs on AWS, so decide this later in an
  infra spec.
- The delivery surface. The Flutter app is milestone 1. A prior idea used a
  Telegram bot on another project's setup, which does not exist here.

## 12. Legal notes

This is not legal advice. It is recorded to keep data sourcing at low risk.

- Do not scrape full catalogs in bulk. Pull single facts, not whole databases.
- Respect robots.txt and rate limits.
- Do not bypass a login or a CAPTCHA.
- GDPR applies only if the app scrapes personal data.
- Get real legal advice before this grows past a personal project.

API keys and business-feed credentials are secrets. Never commit them.
