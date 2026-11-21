# Paid courses, ownership of transactions, and access — normative v3

## Product boundaries

The platform is free to use for creators who publish free courses: no listing, enrollment, hosting or platform fees. A creator may instead opt in to a one-time paid course and agrees to a **platform commission of 5% (500 basis points)** on the eligible course subtotal after discounts, excluding any sales tax/VAT. Payments do NOT originate from YAML declarations. D1 stores the authoritative offer, ownership and commercial policy. `course.yaml` remains a portable pedagogical manifest; it must contain no payment credentials, seller account identifiers, entitlements, private API URLs, customer lists, or trusted prices. Subscription billing, recurring platform fees, advertising and certificate-only purchases are out of scope for v3.

No creator can sell until verified repository administration, Stripe connected-account onboarding, confirmed `charges_enabled`, applicable tax/merchant review, refund policy and paid-content delivery checks have passed. Payout and compliance eligibility is not inferred from a Firebase account. Use Stripe-hosted onboarding and payment pages, rather than writing financial/KYC or credit-card forms. Store Stripe IDs and event records only in D1; Stripe is authoritative for card processing and financial settlement.

**Charge flow decision gate:** Prefer Stripe Connect **direct charges** with creator as the eligible merchant and the platform collecting an application fee, subject to account eligibility, supported regions, legal merchant-of-record determination, and exact Connect pricing. This normally assigns processing-fee/refund/chargeback exposure to the connected account, but integrations and pricing configurations vary. Do not assume that direct charges always eliminate all platform Connect costs. If direct charges are unavailable, a destination-charge design may be evaluated separately; it changes liability and could make a 5% fee unprofitable on small purchases. No migration to destination charges without explicit product-owner approval. See [Stripe Connect direct charges](https://docs.stripe.com/connect/direct-charges), [Connect pricing](https://stripe.com/en-bg/connect/pricing), and [Marketplace guide](https://docs.stripe.com/connect/marketplace).

## Financial rules (server-controlled)

- One-time access purchase for one course, to one buyer Firebase UID. Creating an account and browsing a course is free; no charges for free courses.
- Offer is `{courseId, offerId, version, currency ISO-4217, priceMinor integer >0, feeBasisPoints=500, status}`. All prices/fees must be integers in the currency's minor unit; no floating-point money. USD/EUR examples use 100 minor units per major unit; currency-specific exponents come from vetted Stripe currency tables.
- `commissionMinor = round_half_up(eligibleSubtotalMinor * 500 / 10000)`; eligible subtotal excludes sales tax/VAT and applies validated discounts. Refunds reverse the corresponding proportional platform fee where supported and subject to provider fee rules. Record exact fee/FX/rounding snapshots at purchase.
- **Never** trust `price`, `fee`, seller account, course status or discount in the Flutter request, redirect URL, or GitHub YAML. Fetch a versioned D1 offer and create the provider checkout using that snapshot.
- Display final payer-facing price inclusive/exclusive of applicable tax as law requires, seller identity, refund policy and platform commission disclosure before confirmation. Price changes create a new immutable offer version; existing purchases retain their snapshot and access.
- Creator's paid course may optionally publish selected PUBLIC previews and metadata, but the purchased materials themselves MUST be access-controlled. A public Git repository (or unlisted YouTube video) is not access-controlled. A private GitHub repo plus platform-authorized private delivery is a supported pattern, as is an external provider offering short-lived authenticated streaming URLs. Instructors bear storage/video costs, but must use an approved provider for paid content.
- For all paid and private content, deny unauthorized `manifest`, `content`, `folder`, `download` and metadata routes. Return no private GitHub URLs or GitHub App tokens. Expire scoped download links quickly; use `Cache-Control: private, no-store` for sensitive metadata. Files can still be copied by legitimate students; this is access control, not DRM.
- Free-course access must remain unaffected by payment-provider failure; do not call Stripe merely to enroll in a free course. Free catalog browsing may be anonymous.

## Creator onboarding and checkout lifecycle

1. An already verified course owner elects paid mode. A Worker creates/reuses a Stripe Connect onboarding link for *that instructor's* account; link expires and cannot be used to impersonate another creator. The platform sees only account status and required provider IDs, not raw KYC documents.
2. Worker checks live Stripe connected account status and D1 `creator_payment_accounts` (`charges_enabled`, terms acceptance, merchant controls). Review tax responsibilities and creator eligibility; only then allow the owner to publish an immutable price offer and change `sales_status=active`.
3. Student opens course landing page; public catalog reveals price and approved previews, not protected files. Learner signs in, chooses Purchase, and calls authenticated `POST /courses/{courseId}/checkout`.
4. Worker checks active offer, creator payout eligibility, country/currency rules, and whether learner already has an active entitlement. It creates an idempotent internal order, then a Stripe-hosted Checkout Session with server-generated price and 5% application fee using the approved charge configuration; stores session ID. Avoid duplicate charges on retries using idempotency key derived from internal order ID.
5. Browser redirects to hosted Checkout. The success URL displays `Processing payment`; it NEVER grants course access. An attacker can edit redirect query strings.
6. Stripe sends signed webhook; Worker validates signature against RAW bytes, records unique Stripe event ID, associates it to the exact verified Checkout/PaymentIntent and buyer, checks paid amount, currency, connected account, course and offer snapshot, and transacts `paid order + active entitlement + enrollment` in D1. Events can be duplicated/out of order: make handler idempotent and repairable.
7. On failure/expiration, no paid entitlement. On full refund or confirmed chargeback, record a negative adjustment and revoke access under published policy; on partial refund apply an explicit policy, not an accidental automatic revoke. Ensure lawful retention of historical grades, certificates and receipts as appropriate.
8. Account disconnect, KYC restriction or deleted course pauses new sales, but must not silently erase established payment histories, public certifications or learner rights. Supply operational refund/fulfillment policy.

## Seller of record, taxes, and compliance

Determine and document seller/merchant of record before going live. Stripe Connect is a payment facilitator, NOT a blanket tax/VAT or legal compliance substitute. For EU B2C digital course sales, analyze VAT place-of-supply, VAT One Stop Shop, applicable educational exemptions, invoices, and the creator/platform legal relationship with qualified counsel. Do not automatically assert that every educational course is VAT exempt. Verify buyer jurisdiction and consumer rights, including any applicable withdrawal/consent rules. Ensure Terms of Service, Privacy Notice, seller disclosures, IP policies, moderation/reporting, and refunds are defined before paid publishing. Provider coverage and additional charges vary by country and payment method. Selling courses involves compliance support and disputes beyond tiny hosting bills.

## Mobile storefront requirements

Flutter mobile apps and Web use the same D1 course entitlements, but payment acquisition rules are DIFFERENT. On iOS/Android app stores, digital courses used inside the app may be subject to Apple/Google in-app purchasing rules, store fees, geographic exceptions or permitted external purchasing entitlements. **Release web Stripe purchases first.** Native apps may consume previously purchased access only where store policy permits; default native builds MUST hide checkout/price-linked external payment CTAs until policy/legal review for each store/region. Do not presume a generic web browser link in an app is compliant. If native IAP is later added, create a separate purchase provider and provider-specific entitlement verifier; never conflate IAP revenue with the 5% Stripe fee model.

## Payment security and tests

- Successful redirect without valid Stripe webhook -> NO entitlement.
- Replay event or concurrent checkout -> no duplicate entitlement or double charge; unique event and order processing.
- Forged session ID, price, discount, creator account, or user UID -> rejected.
- Concurrent refund and webhook settlement -> deterministic final entitlement state, audited.
- Owner loses GitHub App/private repo access -> pause sales, notify and allow refunds; do not charge for unavailable content.
- Course switches free -> paid or paid -> free -> preserve historical entitlements and instructor-configured policy; do not revoke existing buyers merely because offer changed.
- Account data deletion request -> enforce retention schedules for tax/payment records without leaking private payment data.

## API additions

`POST /creators/payments/onboard`; `GET /creators/payments/status`; `GET /courses/{courseId}/offers`; `POST /courses/{courseId}/offers/configure`; `POST /courses/{courseId}/checkout`; `GET /orders/{orderId}`; `GET /courses/{courseId}/entitlement`; `POST /stripe/webhook`. All are protected per user and owner authorization except the signed webhook and public sanitized offers. Request/response DTOs and response codes should be refined in `api/openapi.yaml` before coding; the above security rules are mandatory.
