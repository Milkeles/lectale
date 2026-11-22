# Task: build the static website and move the app under /app

| Intake | |
|---|---|
| **Why** | The owner approved the landing page layout (docs/ux/concepts/landing/, commit dc27803) and wants a standard landing page. ADR-0014 puts static HTML at `/` and the Flutter web app under `/app/`. Requirements: V4-COST-06 (no tracking), V4-CACHE-04 (static pages invoke no Worker), security review R16 to R22 (docs/security/reviews/2026-11-21-auth-and-landing-requirements.md). |
| **Simpler** | Hand-written HTML and CSS taken from the concept, one small build script, no framework, no bundler. Not building: the catalog page with real data (the catalog API is milestone M10), real log-in (M3), the hero variants (the owner is still choosing; the hero is one swappable file). |
| **Ready-made** | QR codes with the `qr` npm package (MIT or Apache-2.0, no dependencies; docs/research/2026-11-21-landing-references.md). Fonts are the official WOFF2 files already in the concept. Difficulty M, about 300 lines of build script and tests, plus the moved pages. |
| **Security** | Trust boundary: what the public page loads and the headers it is served with. Content Security Policy and security headers per R18; download links only to this project's GitHub releases (R21); the QR code encodes the canonical host (R22). A security review and a Codex review of the headers are needed before merge. |
| **Verify** | `node apps/site/test/site.test.mjs` passes. `npm --prefix apps/edge_api test` still passes. The local preview (`npx wrangler dev` in apps/edge_api, after the build) serves `/` as the landing page, `/app/` as the Flutter app, `/download/android` as a redirect, and the headers below. |

## What to build

1. **`apps/site/`**: the source of the public site.
   - `src/index.html`: the landing page from `docs/ux/concepts/landing/index.html`, with the hero moved into `src/partials/hero.html` so it can be swapped. Keep the current concept hero for now, but use the chosen copy: headline "Your course, online in minutes.", subheading and buttons from `docs/ux/copy/landing.md`, "Chosen hero".
   - `src/site.css`, `src/fonts/` (with the licence files), `src/covers/`, `src/logo.svg`, copied from the concept.
   - Leave out the concept-only pages: catalog, login, create-account and app-home. "Log in" and "Create account" link to `/app/`. "Catalog" links to the landing page's catalog section until the catalog exists.
   - `build.mjs`:
     - inline the hero partial;
     - generate the Android QR code as SVG with `qr` (it encodes `https://lectale.fervorgames.workers.dev/download/android`; read the host from one constant so a custom domain is a one-line change);
     - copy everything into `apps/site/dist/`.
   - `package.json` with `qr` pinned to an exact version, and a `package-lock.json`.
2. **The combined assets folder.** The deploy assembles `apps/site/dist/` plus the Flutter web build into one folder, with the Flutter build at `app/` and built with `flutter build web --release --base-href /app/`. Point `assets.directory` in `apps/edge_api/wrangler.jsonc` at that folder.
   - The app keeps hash URLs (ADR-0014).
   - Check in the Cloudflare docs whether `not_found_handling: "single-page-application"` should stay or become `"404-page"` now that `/` is a real page. Fetch developers.cloudflare.com pages as Markdown at `<page>/index.md`. Add a static `404.html` from the site if that mode is chosen.
3. **Headers and the redirect.** Find out, from the fetched Cloudflare docs, whether Workers static assets honour `_headers` and `_redirects` files.
   - If they do, add `_headers` with the R18 policy for site pages:
     ```
     default-src 'none'; style-src 'self'; font-src 'self'; img-src 'self'; script-src 'self'; connect-src 'none'; base-uri 'none'; form-action 'self'; object-src 'none'; frame-ancestors 'none'; upgrade-insecure-requests
     ```
     plus `X-Content-Type-Options: nosniff`, `Referrer-Policy: strict-origin-when-cross-origin` and `Permissions-Policy: camera=(), microphone=(), geolocation=()`.
   - Add `_redirects` with `/download/android https://github.com/Milkeles/lectale/releases/latest/download/lectale-android.apk 302`.
   - Don't apply the site CSP to `/app/*`: the Flutter app needs its own policy, which is spike S3.
   - If the files aren't supported, say so in your report and stop at the redirect. Don't move routes into the Worker without asking.
4. **The workflows.**
   - Update `.github/workflows/deploy-preview.yml` to build the site, build Flutter with `--base-href /app/`, assemble the folder and deploy.
   - Keep actions pinned by SHA and run `zizmor --offline` on any workflow you change.
   - In `.github/workflows/ci.yml`, add a job that builds the site and runs its tests.
5. **`apps/site/test/site.test.mjs`**, using Node's built-in test runner with no new test dependency:
   - every `href` and `src` in `dist/index.html` is same-origin, or a `https://github.com/Milkeles/lectale/` URL, or a `mailto:` (R17, R21);
   - every download link matches `^https://github.com/Milkeles/lectale/releases/`;
   - the QR SVG exists, and the URL printed beside it equals the constant;
   - `_headers`, if present, contains the CSP above;
   - no `<script>` has inline content.
6. **Docs.** `apps/site/README.md` says how to build and preview. Update `docs/ux/concepts/landing/README.md` to point at `apps/site` as the production source.

## Boundaries

- Don't deploy, and don't change secrets or environments.
- Don't touch the Flutter app's Dart code. The base-href change is a build flag only.
- Don't add other dependencies.
- Commit nothing. The orchestrator reviews the diff and merges.
