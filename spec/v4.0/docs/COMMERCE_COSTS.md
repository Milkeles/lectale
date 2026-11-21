# Payment economics and platform ownership — v3

Do not treat 5% of course sales as 5% operating profit. Fees are based on eligible subtotal net of discounts, excluding VAT. The platform and creators must agree who bears processing, Connect monthly active-account, payout, FX, refunds, dispute, tax, video/storage and consumer-support costs. Stripe Bulgaria lists an illustrative standard EU card processing rate of **1.5% + €0.50**; Stripe Connect pricing configuration may additionally charge the platform **€4 per monthly active account** and **0.25% + €0.60 per payout** when the platform chooses to manage pricing; exact configuration must be confirmed before launch, not inferred.

| Course subtotal (illustrative EUR) | Platform 5% gross | Card fee if 1.5% + €0.50 | Platform net if it bears that card fee, before any other fees |
|---|---:|---:|---:|---:|
| €5.00 | €0.25 | €0.575 | -€0.325 |
| €10.00 | €0.50 | €0.65 | -€0.15 |
| €20.00 | €1.00 | €0.80 | +€0.20 |
| €50.00 | €2.50 | €1.25 | +€1.25 |

If the eligible direct-charge configuration assigns processing to the connected creator, the platform may receive the gross 5% commission before any Connect/platform fees or tax. This improves unit economics but reduces creator proceeds. Example: 100 €20 sales = €2,000 subtotal, €100 gross platform commission, €80 illustrative card fees; platform net before other fees would be €20 if it pays those card fees, or €100 before other fees if the creator pays them. This is *not* a guaranteed pricing quote.

**Hard cost gates:** (a) owner not onboarded -> no paid course; (b) direct charges ineligible or platform fee pricing unknown -> block paid sales pending pricing review; (c) tax seller of record unknown -> block sales; (d) private video/content delivery not secured -> block paid sales; (e) native app purchase compliance not reviewed -> web-only checkout. Free-course infrastructure cost unchanged.

Sources: https://stripe.com/en-bg/pricing ; https://stripe.com/en-bg/connect/pricing ; https://docs.stripe.com/connect/marketplace ; https://docs.github.com/en/actions/concepts/billing-and-usage ; https://developer.apple.com/app-store/review/guidelines/ ; https://support.google.com/googleplay/android-developer/answer/9858738 ; https://europa.eu/youreurope/business/finance-and-tax/vat/one-stop-shop/index_en.htm
