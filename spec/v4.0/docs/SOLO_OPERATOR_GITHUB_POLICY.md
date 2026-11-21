# Solo-operator compliance, Terms responsibility allocation, and GitHub paid-content policy — v3.2

## Boundaries
This platform is built and operated by one person. Do not require outside-counsel sign-off, a separate moderation team or a DPO without a legal trigger. **No contract can waive mandatory legal duties.** Assign instructor content responsibilities in the publishing agreement, retain the platform's responsibility for its own UI, personal data, payments and enforcement of platform access.

## GitHub findings to preserve
1. GitHub's normal Terms do NOT contain a categorical ban on charging access to the contents of private repositories. GitHub Sponsors documents paid access to private repositories; it is not a blanket commercial API authorization: https://docs.github.com/en/sponsors/receiving-sponsorships-through-github-sponsors/managing-your-sponsorship-tiers
2. GitHub Pages may not serve as an e-commerce storefront or commercial SaaS hosting service; use Cloudflare Pages: https://docs.github.com/en/site-policy/github-terms/github-terms-for-additional-products-and-features
3. GitHub API H conditions: do not share tokens to bypass rate limits; high-throughput/resale of GitHub Service has separate concerns: https://docs.github.com/en/site-policy/github-terms/github-terms-of-service
4. Public GitHub repositories cannot be paywalled; GitHub grants viewer/fork rights through the service. Paid contents require actual private access control. The creator must grant our app explicit limited display/transmission rights, including for public content and any private material.
5. GitHub AUP forbids infringing content and allows bandwidth/repository action for excessively abusive file hosting: https://docs.github.com/en/site-policy/acceptable-use-policies/github-acceptable-use-policies

## Accessibility legal scope
- Bulgarian State Gazette official law: https://dv.parliament.bg/DVWeb/showMaterialDV.jsp?idMat=233836 (Article 46(3): qualifying microenterprises offering services exempt from specified service-accessibility duties; Article 2(3)(4): qualifying third-party content excluded). EU microenterprise thresholds and circumstances must be documented honestly. Neither rule exempts the entire platform from unrelated law.
- Keep platform-controlled UI at WCAG 2.2 AA as engineering target for a good product; require source-content accessibility warranties where applicable; do not pretend all instructor-provided PDFs automatically meet it.
- A creator's third-party status is fact specific: if the platform creates, controls or commissions material, the third-party exclusion may not hold. Make reports and alternatives possible.

## Suggested instructor contract topics (not a substitute for final local terms)
- Instructor represents owning or licensing all source material and recorded-person likenesses; agrees to avoid rights infringement and unlawful personal information in uploaded recordings.
- Instructor supplies accurate course details, price, prerequisites if any, accessibility features, promised support, refund terms and maintains their GitHub account, LFS quotas, video provider, course availability and adequate material accessibility where legally required.
- Instructor grants platform a nonexclusive, term-limited license to retrieve, display, render and serve authorized content to learners for catalog/teaching functionality; rights to redistribute content beyond the service are not implied.
- Instructor accepts that the platform can delist, suspend, restrict platform API access and stop collecting payments if an infringement/security/fraud report or lawful order warrants it; this does not remove their repo from GitHub.
- Operator remains responsible for its own user data, privacy and security, accurate fee disclosures and payment controls, and mandatory consumer duties according to the parties' actual legal roles.

## Controls and low-operations UX
- `POST /reports`: course, URI, reason, short narrative, contact and evidence; safely store and queue. Owner can `delist`, `suspend`, `freeze_enrollment`, `freeze_payments`, `disconnect_github_integration` and restore, with audit/reasons, without modifying GitHub repository. Expose contact/response workflow as actually applicable.
- No blanket auto-ban based solely on unauthenticated reports. Rate-limit reporting, store status and provide human attention for serious or credible infringement reports. Solo owner can act without a team.
- GDPR: privacy policy + opt-out/data export/delete request flow; no unconditional DPO mandate; grades and certificate names are personal data; necessary session cookies do not require cookie consent; no tracking by default and click-to-load third party videos.
- Paid e-commerce: separate seller terms and clearly label instructor identity; declare platform fee 5% *of eligible subtotal before applicable tax* and who pays payment costs. Use Stripe Connect onboarding but do not assume it settles VAT, invoices, seller identity or refunds. Do not promise all digital sales have waived withdrawal rights. Country-specific policies may require restrictions on launch markets.

## Product-owner self-review release checks
- SOLO-001 instructor Terms contain content licenses and rights/recorded-person responsibilities.
- SOLO-002 paid materials never become public through a GitHub source URL, shared token, README or previews.
- SOLO-003 all public-facing app/checkout hosting uses Cloudflare Pages, not GitHub Pages.
- SOLO-004 note explains GitHub usage limits and provides policy links.
- SOLO-005 document operator's microenterprise status and applicability of third-party-content exception; do not treat unrelated rights as waived.
- SOLO-006 reports can be submitted and course display/paid access can be disabled without deleting GitHub repositories.
- SOLO-007 accurate operator identity, support contact, terms/privacy/cookie policy and applicable payment/consumer disclosures published; no fictitious legal entity.
- SOLO-008 permissions, student data and grades remain private; external media tracking consent (where necessary) is enforced.
- SOLO-009 checkout completed by verified webhook; refund/dispute tests and seller payout responsibilities documented.
- SOLO-010 creator self-check recorded with date, markets enabled, legal/policy versions, unresolved issues and links to provider sources. Outside counsel NOT required by system. If lawfulness of a specific market or transaction is unresolved, disable only that paid feature/region.
