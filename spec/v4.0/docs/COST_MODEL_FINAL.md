# Cost model — V4 normative, planning not billing quote

## Fixed architecture
Cloudflare Pages static Flutter Web (free static allowance), Cloudflare Workers/Pages Functions for `/api` only, D1 metadata/permissions, Firebase Auth standard email/social sign-in, GitHub instructor-owned content/submission repositories and Git LFS (if safe delegated upload demonstrated), YouTube/video provider instructor-owned, Stripe Connect for optional paid courses. Free `.pages.dev` host requires no domain payment; custom domain adds only optional registrar renewal and potentially DNS-related service charges chosen by owner. Native app distribution may have independent developer fees. Do not add a dedicated search product, database server or private object store.

## Assumptions
MAU monthly students; 40 dynamic API requests/student/month without catalog, plus 10 catalog page GETs/student/month at 20 results/page for the discovery scenario; 80 D1 rows read/student/month base plus 200 returned catalog result rows/student/month (indices may read more and should be measured); 4 writes/student/month base, indexed write overhead extra; ~2 ms or 10 ms CPU per *executed* dynamic request; 30 days evenly distributed; <5 GB D1 data, no large binary through Functions; free standard Auth methods, no SMS. Actual catalog view rate, CPU, retry bursts, and enrollment/payment operations may differ. A cached Worker GET counts as a request, while CPU may be nearly zero on hit.

## Verified public pricing links (November 2026)
- Cloudflare Workers: https://developers.cloudflare.com/workers/platform/pricing/ ; Free 100k requests/day (hard daily ceiling); Paid $5/mo includes 10M req and 30M CPU-ms; additional $0.30/M req and $0.02/M CPU-ms; dynamic requests served from Workers Cache still count.
- D1: https://developers.cloudflare.com/d1/platform/pricing/ ; Free 5M rows read/day + 100k written/day + 5 GB; Paid includes 25B read and 50M written rows/month + 5 GB, beyond storage $0.75/GB-month. Indexed writes affect counted rows. No D1 egress charges.
- Pages/Functions: https://developers.cloudflare.com/pages/functions/pricing/ ; direct static traffic free/unlimited; Functions follow Worker pricing.
- Firebase: https://firebase.google.com/pricing and https://firebase.google.com/docs/auth ; Standard Firebase Auth email/social no MAU charge in ordinary configuration; optional Identity Platform/SMS have different costs.
- Git LFS: https://docs.github.com/en/billing/concepts/product-billing/git-lfs ; GitHub Free account has 10 GiB LFS storage and 10 GiB monthly download allowance; creator owns bills; not included in platform total.

## Worker cost calculation, paid tier
For N student MAU, requests = N*{40 or 50}; executed_CPU_ms = executed_request_count * CPU_ms; Worker charge = $5 + max(0,(requests - 10M)/1M)*$0.30 + max(0,(executed_CPU_ms - 30M)/1M)*$0.02. When all requests fit the Free daily limit and CPU per executed request meets the Free CPU limit, Worker amount can be $0. Use actual 95th-percentile daily and per-invocation CPU, NOT monthly average, to determine Free feasibility. D1 costs are separate if quotas exceeded. Platform payment processing, chargebacks, VAT, email/phone services and customer support are excluded.

| MAU | Base requests | Catalog-added requests | Total | Low CPU bill (2 ms/exec, no cache hits) | Higher CPU bill (10 ms/exec, no cache hits) |
|---:|---:|---:|---:|---:|---:|
| 1,000 | 40k | 10k | 50k | $0 if Free daily/CPU limits met | $0 if Free limits met |
| 10,000 | 400k | 100k | 500k | $0 if Free limits met | $0 if Free limits met |
| 50,000 | 2M | 0.5M | 2.5M | $0 if Free daily/CPU limits met | $0 if Free limits met |
| 100,000 | 4M | 1M | 5M | $5.00 | $5.40 |
| 250,000 | 10M | 2.5M | 12.5M | $5.75 | $7.65 |
| 500,000 | 20M | 5M | 25M | $9.90 | $13.90 |
| 1,000,000 | 40M | 10M | 50M | $18.40 | $26.40 |

These amounts include the $5 paid minimum for those cases above Free's typical daily limit. E.g. at 100k MAU + catalog, monthly traffic ~166,667 dynamic requests/day, above Free 100,000/day. At 50k MAU + catalog, ~83,333/day could fit, assuming smooth distribution, CPU budget and free feature limits. Worker cache hits lower CPU cost but do NOT lower Worker request charge; they do reduce D1/GitHub reads and latency. D1 example at 1M MAU with 200 catalog rows each, 200M extra rows/month -> within 25B paid included IF indexes keep reads reasonably bounded. Monitor actual `rows_read` because scanned rows may exceed returned rows.

## Domain
- No custom domain: `https://<project>.pages.dev`; $0 registrar charge. Same-host `/api` and `__Host-course_session`; Firebase Auth domain authorized explicitly.
- Custom domain: canonical HTTPS domain on Cloudflare Pages; DNS and TLS configured, new OAuth callback & Firebase domain allowlist; monthly hosting rates same. Annual registrar fee depends on TLD/registrar; do not invent flat `.com` fee. Redirect old `.pages.dev` and update session origin safely. If a payment provider charges for custom branding, evaluate separately.

## What could add cost
Instructors' LFS allowance/overage; paid video provider; GitHub Actions grading minutes; native app distribution; optional Stripe Connect/payment processing, refunds/chargebacks/payout FX; DNS/domain renewals; auth SMS/Identity Platform; excessive abuse/spikes; D1 stored data >5 GB; error logs or retention, additional Cloudflare services only if intentionally enabled. The platform's 5% fee is a gross share of eligible sale subtotal excluding VAT, NOT guaranteed profit. If platform bears card costs, inexpensive courses may lose money; prefer verified Stripe Connect configurations that correctly allocate charges and liabilities.

## Validation rule
Cost claims MUST be labeled scenarios with date and assumptions. No implementation task should choose paid infrastructure or new middleware solely because the user count is large. Measure requests, CPU ms, D1 rows and GitHub API cache hit rate first, and set alerts plus per-user/owner limits.
