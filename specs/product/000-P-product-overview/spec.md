---
id: "PROD-000"
status: "DRAFT"
updated: "2026-09-21"
---
# 000 — Product overview

**Status note:** Draft. The product authority: the analog of the `core/`
constitution for the application domain. Every other `product/` spec cites it.

**Complexity:** Medium
**Risk:** Low — a document, but it fixes the module boundaries every feature spec inherits.
**Estimated cost:** ~1 day
**Recommended model:** Sonnet.
**Depends on:** [core/000-constitution](../../core/000-D-constitution/spec.md) (repository and platform rules), the Flutter shell ([core/070](../../core/070-P-flutter-shell-trim/spec.md), [core/080](../../core/080-P-flutter-config-and-hello/spec.md)) as the delivery surface.
**Lifecycle class(es) touched:** None (defines the product; owns no resource).

## Scope

What Ahorro is and how its value is decomposed. A shopper photographs a
grocery receipt; the app shows where the same basket cost less, per item, and
later recommends where to shop next. This spec fixes the two user flows, the
pluggable analytics modules and their contracts, the data-sourcing preference
order, and the constraints those choices must respect.

Excludes: per-module implementation specs (`product/010+`, one per module) and
their internal algorithm choices; every platform and infrastructure rule,
which `core/` already owns; storage engine, delivery surface beyond the
Flutter shell, and the free/paid price point — all open (see Open Questions).

## Requirements

1. **Two flows, one module set.** The product MUST deliver exactly two user flows, both composed only from the modules in Requirement 3:
   - **Flow A — receipt → verdict (reactive).** Photograph a receipt; the app parses it, normalizes items, and recomputes the same basket at competing chains, returning a total delta plus a per-item breakdown. Composition: M1 → M2 → M3 → M4 → (log to M7) → M8 gate.
   - **Flow B — history → list → "buy it here" (proactive).** From accumulated history the app builds a recurring shopping list and recommends where to shop next, optionally split across stores. Composition: M5 → M6 (using M3 + M4) → M8 gate.
2. **Trust over headline.** Every comparison shown MUST be justified per item, never a single black-box number. A number the user cannot trace to items is not shippable.
3. **Pluggable modules with stable contracts.** The analytics MUST be decomposed into independent modules that communicate only through the input→output contracts below, never through each other's internals. Each MUST be independently replaceable and independently testable against fixture data (e.g. M4 runs on canned prices before M3 is real). A module MAY start as a cheap stub and be upgraded without touching the flows or the other modules.

   | Module | Responsibility | In → Out (contract) |
   |--------|----------------|---------------------|
   | **M1 · Receipt Ingestion** | Photo → structured receipt | image → { store, date, lines[name, qty, unit_price, total] } |
   | **M2 · Product Normalization** | Receipt text → canonical product | raw line → { canonical_id, confidence } or `no_match` |
   | **M3 · Price Index** | Current prices per store | canonical_id → { store → price, as_of } |
   | **M4 · Basket Comparison** | Recompute basket elsewhere | basket + M3 → { per_store total, per_item delta, substitutions } |
   | **M5 · Shopping Profile** | Aggregate history into habits | user's baskets → recurring items, cadence, typical spend |
   | **M6 · List & Recommender** | Predict list, pick store(s) | profile/list + M3/M4 → ranked stores, split-basket plan |
   | **M7 · Savings Ledger** | Track potential/realized savings | comparison results over time → trend, lifetime savings |
   | **M8 · Subscription / Paywall** | Gate value, drive the CTA | user + entitlement → what's unlocked vs. teased |

4. **Confidence is passed through, never hidden.** M2's `no_match` and low-confidence lines MUST surface in the flows as "no comparison available" rather than a guess. A per-item confidence threshold MUST gate whether a comparison is shown (the threshold value is an Open Question).
5. **Edge cases are explicit, not silent.** Both flows MUST handle: store-brand items with no cross-store equivalent (flag "no comparison available", do not guess); a "similar set" substitution when a competitor lacks the exact item (clearly labelled as a substitution); a low-quality receipt image (best-effort parse with uncertain lines flagged).
6. **Normalization chain.** Product matching MUST run receipt line → retailer catalog (same naming, easy) → canonical product (Open Food Facts, EAN-indexed) → cross-store comparison, falling back to LLM semantic matching (name + category + size) for store-brand items with no cross-store barcode. Open Food Facts is the canonical dictionary; it is weak on private-label items, which is why the retailer-catalog step exists.
7. **Data-sourcing preference order.** Price/catalog data MUST be sourced in this cost/effort order, using the cheapest tier that covers a chain: (1) a B2B comparator feed where one is available (notably for Mercadona, which has no easily public catalog); (2) ready-made marketplace scrapers for prototyping matching logic; (3) own scrapers only where the first two fall short on cost or coverage. MVP chain coverage starts with 3–4 chains that have accessible prices and treats a no-public-catalog chain as a gap to fill via tier 1.
8. **Lawful sourcing.** Data collection MUST respect `robots.txt`, rate-limit, avoid republishing full catalogs, and never bypass authentication or CAPTCHA (see Legal notes). This binds every module and every scraper choice.
9. **Value is gated, not walled.** M8 MUST let the free tier deliver a teaser (e.g. a headline number or a capped number of receipts) and reserve the full per-item breakdown, all chains, history, and ongoing recommendations for the paid tier. The exact free/paid line is an Open Question; that one exists is not.
10. **Nothing sensitive in Git.** Per [core/000](../../core/000-D-constitution/spec.md) Requirement 4, no secret, root domain, or `fqdn` enters this spec or any `product/` spec. Data-provider API keys and B2B credentials are secrets and MUST NOT be committed.

## Implementation hints

- Split this overview into one child spec per module (`product/010-P-receipt-ingestion`, `020-P-product-normalization`, …) and one per flow, numbered in tens with gaps. Each child cites this spec for the contract it implements.
- Build M4 and M8 first against fixtures: basket comparison and the paywall gate carry the demo value and need neither real prices (M3) nor real OCR (M1) to be exercised.
- The module contracts are the test seams — write contract fixtures before wiring a module to a real data source.
- Existing Spanish comparators (SoySuper, Super TRuper, OCU Market, OkLista, Carritus) validate the category and are worth studying for coverage and matching behaviour; they are reference, not a dependency.

## Testing / acceptance criteria

- `make specs-check` passes with `product/` registered and this spec's front matter valid (`id: PROD-000`, status matching the `P` folder letter).
- Each of Flow A and Flow B is expressible as a composition of the Requirement 3 modules with no step that reaches into another module's internals.
- A reader can point to the module that owns each of: OCR, canonical mapping, price data, basket delta, habit modelling, recommendation, savings history, and gating — with no responsibility owned by two modules.
- Every child `product/` spec, when added, cites this spec for the contract it implements and touches only its own module.

## Open questions

- **Delivery surface.** The MVP surface is the Flutter shell in this repository (`core/070`, `core/080`). A prior sibling project prototyped a Telegram-bot surface reusing that project's own infra; that infra does not exist here, so a bot surface is out of scope until a spec adds it deliberately.
- **Storage engine.** Product/price storage was sketched against another project's analytics stack (ClickHouse / BigQuery). This repository runs on AWS with Argo-owned Kubernetes objects and Terraform-owned AWS resources; the storage choice here is undecided and belongs in a future infra spec, not assumed from the prior project.
- **Confidence threshold.** The actual per-item confidence value below which a comparison is hidden rather than shown.
- **"Similar set" definition.** What qualifies a substitution — same category plus a size band, or something tighter.
- **Free/paid line.** Where exactly the paywall sits per flow (headline-only vs. capped receipts for Flow A; whether Flow B is fully paid).
- **Flow B confirmation.** Whether the predicted list needs explicit user confirmation or is auto-generated and editable.
- **B2B terms.** Whether to pursue a B2B comparator feed for the no-public-catalog chains, and on what terms.

## Legal notes

Not legal advice; recorded so sourcing choices stay on the low-risk side.

- Main risks are EU/Spain database *sui generis* rights (systematic full-catalog scraping is higher risk than pulling individual facts), terms-of-service violations (civil/contract, not criminal), and unauthorized-access law (only if bypassing security/CAPTCHA, not for public pages).
- GDPR is not engaged unless personal data is scraped.
- Lower-risk practices, already bound by Requirement 8: respect `robots.txt`, rate-limit, do not republish full catalogs, do not bypass auth/CAPTCHA.
- Obtain a real legal consult if this grows past a personal project.
