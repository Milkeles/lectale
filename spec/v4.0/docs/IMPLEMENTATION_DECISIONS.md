# One-page implementation decisions — V4 authoritative

| ID | Decision | Result |
|---|---|---|
| DEC-01 | Source URL is the core entry | Valid PUBLIC repository can be opened by link without catalog/registration |
| DEC-02 | Catalog is optional | Built-in catalog for listed managed courses only; listing default OFF; no external search service |
| DEC-03 | Course author owns course repository | Public or private; stable numeric repo ID; no GitHub organization requirement |
| DEC-04 | Full course description | Root `README.md` rendered IN the app; YAML v3 is course outline, not prose description |
| DEC-05 | Any discipline | PDF/video/notebook/markdown/audio/images/text/file/folder viewers; unknown binary fallback; no notebook execution |
| DEC-06 | User identity | Firebase Auth standard; same-origin opaque web cookies + CSRF; native bearer tokens |
| DEC-07 | API/database | Cloudflare Pages `/api/*` Worker/Functions + D1; all sensitive ACL decisions server-side |
| DEC-08 | Files and finance | Instructor-owned GitHub repos + LFS with mandatory secure upload proof; no alternative binary storage; instructor pays LFS/video/Actions |
| DEC-09 | Personal data | D1 authoritative enrollments, grades, purchase entitlements, certificate snapshots; no shared-cache PII |
| DEC-10 | Paid courses | Optional one-time Stripe Connect checkout; 5% eligible subtotal ex VAT; signed webhooks unlock content; no checkout for free courses |
| DEC-11 | Grading | Manual required; GitHub Actions auto/hybrid optional and owner-funded; never execute submitted code in Workers |
| DEC-12 | Accessibility | WCAG 2.2 AA quality requirement irrespective of statutory microenterprise exemption; uploader guidance for accessible PDFs/captions |
| DEC-13 | Legal/maintenance | Solo owner; self-checks and notices; ToS allocates instructor responsibility but never waives mandatory operator duties |
| DEC-14 | Hosting | Cloudflare Pages static no cost tier; optional custom domain; `/api` on same origin |
| DEC-15 | Cache | Public immutable SHA-linked objects and catalog only; never cache private, personalized, grade, session or payment data in shared cache |
| DEC-16 | No speculative implementation | GitHub LFS delegated upload is unverified; keep feature OFF unless end-to-end proof passes; don't invent workaround |

## Non-goals
No server VM, no Flutter notebook execution, no prerequisites/quizzes by default, no hosting uploaded videos on the platform, no mandatory GitHub organization, no automatic GitHub site crawler, no required external counsel sign-off, no advanced recommendation engine, no recurring subscriptions, no separate paid search index.

## Product-owner defaults
Free course: $0 platform fee. Managed course starts unlisted. Open by link works independently. Disabled by default: catalog listing, paid sales, automatic grading, private LFS delegated direct upload, third-party tracking, unsafe HTML, and any unverified authentication-dependent caching. Enabled by default: strict cookies, CSRF, rate limits, accessible rendering, error telemetry without PII, webhook signature verification.

## Conditions requiring human input (not guessable by agent)
Actual brand/domain; Firebase project; Cloudflare account; GitHub App ID/private key; payment provider account and true legal seller/operator identity; applicable tax/withdrawal/market choices; provider account onboarding; release approval for proof-tested LFS flow and optional commerce features. Build safe configuration placeholders and informative setup screens instead of inventing credentials or identities.
