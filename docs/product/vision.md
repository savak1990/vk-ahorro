# Ahorro — Product vision

The product this repository builds, and how its value decomposes. Sections
are numbered so specs and ADRs can cite them. This is the *why* and the
*what*; `specs/product/` holds the *how*, one developable feature per spec.
`docs/architecture.md` covers the platform and delivery architecture; this
document covers the application domain that runs on top of it.

# 1. Core idea

A shopper photographs a grocery receipt right after shopping. The app shows
where the same basket cost less, per item — "−5% at Consum" broken down line
by line, not a single black-box number — and, over time, gets ahead of the
next trip by recommending where to shop. Valencia / Spain first.

The trust rule runs through everything: a number the user cannot trace back
to individual items is not shippable.

# 2. High-level use cases

Two flows carry the product. Both are compositions of the analytics modules
in section 3, and both end in a subscribe CTA — the free tier teases value,
the paywall unlocks the full version.

## 2.1 Flow A — receipt → "how did you do?" (reactive)

The hook: the user acts, the app reacts with a verdict.

1. Photograph a receipt right after shopping.
2. Parse it, normalize items, recompute the same (or a similar) basket at
   competing chains.
3. Feedback: "You paid €47.20. Same basket at Consum: €44.80 (−5%). At
   Carrefour: €48.90 (+3.6%)," with a per-item breakdown so the number is
   trustworthy.
4. CTA: free tier = capped receipts/month or headline number only; subscribe
   to unlock the full per-item breakdown, all chains, and history.

Value: analytics on a purchase already made — low commitment, instant "aha",
no behaviour change needed to try it.

## 2.2 Flow B — history → shopping list → "buy it here" (proactive)

The retention engine: the app learns habits and gets ahead of the next trip.

1. Analyze accumulated history (from Flow A receipts).
2. Build a predicted/recurring shopping list (the typical basket, or one the
   user assembles in-app).
3. Compare that list across chains and recommend where to shop next to
   minimize spend, optionally split-basket ("most at Mercadona, these 3 at
   DIA saves €4").
4. CTA: free tier = a single suggestion or one list; subscribe for ongoing
   recommendations, list building, and multi-store optimization.

Value: forward-looking savings — turns one-off analytics into a recurring
reason to open the app.

## 2.3 Edge cases (both flows)

- Store-brand items with no cross-store equivalent (Hacendado, etc.) → flag
  "no comparison available", do not guess.
- No exact match at a competitor → substitute a comparable product, clearly
  labelled as a substitution.
- Per-item confidence threshold gates whether a comparison is shown vs.
  hidden (threshold value is open — section 8).
- Low-quality receipt image → best-effort parse with uncertain lines flagged,
  rather than a silent wrong reading.

# 3. Analytics modules

The analytics is decomposed into independent modules with stable
input→output contracts. *How* each works internally (LLM, heuristics,
third-party API, own model) stays open and swappable — a module can start as
a cheap stub and be upgraded without touching the flows or the other modules.
Modules communicate only through the contracts below, never through each
other's internals, and each is independently testable against fixture data.

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

Composition:

- Flow A = M1 → M2 → M3 → M4 → (log to M7) → M8 gate
- Flow B = M5 → M6 (uses M3 + M4) → M8 gate

Confidence is passed through, not hidden: M2's `no_match` and low-confidence
lines surface as "no comparison available" in the flows.

# 4. Product normalization strategy

Matching chain: receipt line → retailer catalog (same naming, easy) →
canonical product (Open Food Facts, EAN-indexed) → cross-store comparison.

- **Open Food Facts** — free, EAN-indexed, crowdsourced catalog. Good as the
  canonical cross-store dictionary. Weak on private-label items.
- **GS1/EAN barcodes** — the real standard ID, but Spanish receipts rarely
  print barcodes, so they help build the reference catalog, not parse
  receipts directly.
- **Retailer catalogs** — needed regardless, especially for store-brand
  products with no cross-store barcode. Fall back to LLM semantic matching
  (name + category + size) for those.

# 5. Data sourcing (cost/effort order)

Use the cheapest tier that covers a chain:

1. **B2B comparator feed** — Spain's existing comparator sells B2B (price
   monitoring, "buy now" widgets, APIs). Likely the cheapest legitimate route,
   especially for Mercadona, which has no easily public catalog.
2. **Marketplace scrapers** — pay-per-result, ready-made, good for
   prototyping matching logic before own scraper infra (rough figures:
   Mercadona has a public product API ~$2/1k, Carrefour includes EAN
   barcodes ~$1.20/1k, DIA/Alcampo/Eroski ~$2/1k).
3. **Own scrapers** — most control and lowest marginal cost long-term, most
   maintenance; use only where tiers 1–2 fall short on cost or coverage.

MVP coverage: start with 3–4 chains that have accessible prices (e.g.
Carrefour, Alcampo, Consum, DIA); treat a no-public-catalog chain
(Mercadona) as a gap filled via tier 1.

# 6. Reference — existing competitors

SoySuper, Super TRuper (barcode scan), OCU Market (consumer-org backed),
OkLista, Carritus (older, reportedly covered Mercadona). A well-trodden
category, not fringe — worth studying for coverage and matching behaviour;
reference, not a dependency.

# 7. Legal notes

Not legal advice; recorded so sourcing choices stay on the low-risk side.

- Main risks: EU/Spain database *sui generis* rights (systematic full-catalog
  scraping is higher risk than pulling individual facts), ToS violations
  (civil/contract, not criminal), unauthorized-access law (only if bypassing
  security/CAPTCHA, not public pages).
- GDPR is not engaged unless personal data is scraped.
- Lower-risk practices, treated as binding on any scraper: respect
  `robots.txt`, rate-limit, do not republish full catalogs, do not bypass
  auth/CAPTCHA.
- Get a real legal consult if this grows past a personal project.

Provider API keys and B2B credentials are secrets — never committed
(`specs/core/000-D-constitution` requirement 4).

# 8. Open questions

- **Delivery surface.** MVP surface is the Flutter shell in this repo
  (`specs/core/070`, `080`). A prior sibling project prototyped a Telegram-bot
  surface on that project's own infra, which does not exist here; a bot
  surface is out of scope until a spec adds it deliberately.
- **Storage engine.** Price/product storage was sketched against another
  project's stack (ClickHouse / BigQuery). This repo runs on AWS with
  Argo-owned Kubernetes and Terraform-owned AWS resources; the storage choice
  here is undecided and belongs in a future infra spec.
- **Confidence threshold.** The per-item confidence value below which a
  comparison is hidden.
- **"Similar set" definition.** What qualifies a substitution — same category
  plus a size band, or something tighter.
- **Free/paid line.** Where the paywall sits per flow.
- **Flow B confirmation.** Whether the predicted list needs explicit user
  confirmation or is auto-generated and editable.
- **B2B terms.** Whether to pursue a B2B feed for no-public-catalog chains.

# 9. From vision to specs

A `product/` spec is one short, plannable, testable feature — not this
document. The intended path from here: a product agent reads this vision plus
`docs/architecture.md`, then writes `specs/product/NNN-P-*` specs, each citing
the section above it implements (a module from section 3 or a flow step from
section 2) and each independently planned, estimated, and tested. Suggested
seams to start: M4 basket comparison and M8 paywall gate, both exercisable on
fixtures before real OCR (M1) or real prices (M3) exist.
