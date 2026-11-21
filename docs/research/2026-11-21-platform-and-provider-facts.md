# Platform and provider facts behind the M0 plan

Fetched on 2026-11-21 during planning. Each row names the page it came from. Recheck a row before relying on it for a decision that costs money or weakens security; providers change terms.

## Flutter and packages

| Fact | Source |
|---|---|
| Stable is 3.50.1 (2026-11-20); 3.50.0 shipped 2026-11-11. | storage.googleapis.com/flutter_infra_release/releases/releases_linux.json |
| The in-SDK Material and Cupertino libraries are formally deprecated in 3.50; the standalone `material_ui` and `cupertino_ui` packages could be used from 3.47. `MaterialUiCompatibilityBridge` lets third-party packages that still import the legacy libraries work. Migration: `dart fix --apply --code=migrate_design_widgets`. | docs.flutter.dev/release/breaking-changes/material-ui-and-cupertino-ui |
| `flutter_markdown` is discontinued; replacement is `flutter_markdown_plus`. | pub.dev/packages/flutter_markdown |
| `pdfrx` 3.1.0 and `forui` 0.28.0 require Flutter ≥ 3.50.0. | pub.dev API |
| Platforms: `firebase_auth` 7.1.0 and `firebase_core` 5.2.0 have no Linux. `youtube_player_iframe` 6.0.3 has Android, iOS, macOS and Web. `webview_flutter` 4.14.1 has Android, iOS and macOS. `just_audio` 0.10.6 needs `just_audio_media_kit` 2.1.0 for Linux and Windows. All six platforms: `pdfrx`, `media_kit`, `file_picker`, `go_router`, `flutter_markdown_plus`, `flutter_math_fork`, `dio`. | pub.dev package pages and API |
| `firebase_auth` on web: `Persistence.NONE` keeps state in memory only; `setPersistence` is web-only. | pub.dev/documentation/firebase_auth/latest/firebase_auth/Persistence.html |
| Firebase on Windows is "not intended for production use cases"; Linux isn't listed. The Auth REST API is documented (`accounts:signInWithPassword`, `accounts:signInWithIdp`, `securetoken.googleapis.com/v1/token`). | firebase.google.com/docs/flutter/setup, firebase.google.com/docs/reference/rest/auth |
| No Dart package renders `.ipynb`. `notebookjs` (MIT) is web-only and needs DOMPurify loaded separately in the browser. | pub.dev search "ipynb"; github.com/jsvine/notebookjs |

## Cloudflare

| Fact | Source |
|---|---|
| "Start new projects with Workers." Workers supports most Pages use cases. | developers.cloudflare.com/pages/ |
| Requests to Worker static assets are free and unlimited. `run_worker_first` accepts patterns such as `["/api/*"]`. On Free, matching requests always invoke the Worker and return 429 past the daily limit. | developers.cloudflare.com/workers/static-assets/billing-and-limitations/, …/static-assets/binding/ |
| Pages has no Cron Triggers, Workers Logs or Rate Limiting binding; Workers have all three. | developers.cloudflare.com/workers/static-assets/migration-guides/migrate-from-pages/ |
| Workers Free: 100,000 requests a day, 10 ms CPU per invocation. Paid: $5 a month including 10M requests and 30M CPU-ms. Cache hits are billed as requests but use no CPU. | developers.cloudflare.com/workers/platform/pricing/, …/limits/ |
| D1 Free: 5M rows read and 100k rows written a day, 5 GB total, 500 MB per database, 10 databases, 50 queries per invocation. Paid: 25B reads and 50M writes a month included, 10 GB per database. | developers.cloudflare.com/d1/platform/pricing/, …/d1/platform/limits/ |
| D1 supports FTS5. | cloudflare-docs partial `d1-do-supported-sqlite-extensions.mdx` |
| Workers Logs is on Free (200,000 events a day, 3 days retention). | developers.cloudflare.com/workers/observability/logs/workers-logs/ |
| The Rate Limiting binding takes periods of 10 or 60 seconds and counts per location, approximately. Free-plan availability not verified. | developers.cloudflare.com/workers/runtime-apis/bindings/rate-limit/ |

## GitHub

| Fact | Source |
|---|---|
| GitHub Free includes 10 GiB LFS storage and 10 GiB bandwidth a month. | docs.github.com/en/repositories/working-with-files/managing-large-files/about-storage-and-bandwidth-usage |
| No documented way to give a browser a narrowly scoped LFS upload credential. Not verified either way. | docs.github.com search; git-lfs docs/api/authentication.md |
| `POST /user/repos` accepts user access tokens and installation tokens with Administration write. An installation token acts as the app, so use a user-to-server token for creating an owner's repository. | docs.github.com/en/rest/repos/repos |
| Actions OIDC tokens carry `repository_id` and `job_workflow_ref`. The JWKS URL is not verified. | docs.github.com/en/actions/reference/security/oidc |
| `@octokit/webhooks` states it works in Cloudflare Workers; `@octokit/app` and `@octokit/auth-app` don't mention Workers. GitHub App keys are PKCS#1 while WebCrypto imports PKCS#8. | github.com/octokit/webhooks.js, github.com/octokit/auth-app.js |

## Firebase and Stripe

| Fact | Source |
|---|---|
| Standard Firebase Auth (email and social) has no MAU cap. The Identity Platform upgrade has 50k MAU free, then $0.0055 per MAU. | firebase.google.com/pricing, cloud.google.com/identity-platform/pricing |
| Stripe Managed Payments (Stripe as merchant of record) doesn't support Connect. | docs.stripe.com/payments/managed-payments |
| Destination charges use `payment_intent_data[application_fee_amount]` with `transfer_data[destination]`; `on_behalf_of` makes the connected account the business of record. Stripe Tax calculates VAT, but registration is the seller's job. | docs.stripe.com/connect/destination-charges, …/connect/charges, …/tax/supported-countries/european-union |
| stripe-node exposes `createFetchHttpClient`, `createSubtleCryptoProvider` and `constructEventAsync`. There is no Workers-specific page. | github.com/stripe/stripe-node source |

## Libraries for the Worker

| Fact | Source |
|---|---|
| `@cfworker/json-schema` runs on Workers and supports Draft 2020-12. Ajv's schema compilation needs `eval` or `new Function`, which Workers don't allow. | github.com/cfworker/cfworker (packages/json-schema) |
| `jose` lists Cloudflare Workers as a supported runtime, with `createRemoteJWKSet`. | github.com/panva/jose |
| Hono's `csrf` middleware checks Origin and `Sec-Fetch-Site` only for form content types, so JSON mutations need a session-bound token. | github.com/honojs/website (docs/middleware/builtin/csrf.md) |
| `@cloudflare/vitest-pool-workers` (now renamed `@cloudflare/vitest-plugin`, per npm) runs tests in workerd with Miniflare; `applyD1Migrations` applies migrations in tests. | developers.cloudflare.com/workers/testing/vitest-integration/ |

## Agent tooling

| Fact | Source |
|---|---|
| Subagent frontmatter supports `model` (`sonnet`, `opus`, `haiku`, a full ID or `inherit`), `effort`, `skills` (full content preloaded), `isolation: worktree`, `tools`. No built-in model router exists; `opusplan` uses Opus in plan mode and Sonnet otherwise. | code.claude.com/docs/en/sub-agents, …/model-config |
| Codex concatenates `AGENTS.md` files from the project root down to the working directory. `codex exec` takes `-s read-only|workspace-write`, `-C`, `-o`, `--json`, `-i`. | github.com/openai/codex (codex-rs/core/src/agents_md.rs, codex-rs/exec/src/cli.rs) |
| RTK hooks Claude Code and Codex through PreToolUse; `rtk recall <hash>` or `rtk bypass <cmd>` gives full output. `cargo install rtk` installs a different crate. | github.com/rtk-ai/rtk README, www.rtk-ai.app/docs |
| `npx skills find` returns an empty list on any network error; `https://skills.sh/api/search?q=` works with curl. | github.com/vercel-labs/skills (src/find.ts) |
