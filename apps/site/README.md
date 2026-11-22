# Lectale public site

The landing page uses HTML and CSS with local fonts and SVGs. Edit
`src/index.html` for the page and `src/partials/hero.html` for the hero.
`build.mjs` generates the release links and Android redirect, and uses
the same `ANDROID_QR_URL` for the QR code and printed address (R21–R22).
Change that constant when the canonical host changes. The `qr` package is
used only at build and test time. Its npm metadata describes it as a
“Minimal zero-dependency QR generator/reader”. [qr 0.7.2 metadata](https://registry.npmjs.org/qr/0.7.2)

## Build and test

Run from the repository root with the project's pinned Node version.

```sh
npm --prefix apps/site ci
npm --prefix apps/site run build
node --test apps/site/test/site.test.mjs
```

The public site is in `apps/site/dist/`. The tests check URL allowlists,
decode the QR SVG, and check the security header and script rules.

## Preview locally

```sh
(cd apps/flutter_client && flutter build web --release --base-href /app/)
npm --prefix apps/site run build -- --with-app
(cd apps/edge_api && npm ci && npm run compile:schemas && npx wrangler dev)
```

`--with-app` copies the site into `apps/edge_api/build/assets/` and the
Flutter build into its `app/` subdirectory. `just run-web` uses the same
assembly after `just setup`.

With Wrangler running, check the landing page, app entry point, Android
redirect and the 404 response. The redirect's `Location` points to the APK
in Lectale's GitHub Releases. A Flutter link such as
`/app/#/preview/{repoId}/{sha}` requests the same `/app/` document.

```sh
curl -si http://localhost:8787/
curl -si http://localhost:8787/app/
curl -sI http://localhost:8787/app/main.dart.js
curl -si http://localhost:8787/download/android
curl -si http://localhost:8787/missing/page
curl -si http://localhost:8787/api/health
```

The account links open the app until sign-in ships in M3. The catalog links
open the landing-page preview until M10. The privacy notice, terms and
accessibility links can be added when those pages are published.

Tab starts at “Skip to main content”, then moves through the brand, Catalog,
Download, For instructors, Log in and Create account to “Open a course” and
“Make a course”. “Pause quotes” follows when the orbit is active. Activating
the skip link focuses the main landmark so the next Tab reaches “Open a
course”. Enter opens `/app/#/open`. “Make a course” jumps to the instructor
section. The wider layout shows the orbit at rest with reduced motion or
JavaScript disabled.

## Cloudflare static assets

- Cloudflare says `_headers` rules “will be applied to static asset
  responses” and that “Rules are applied in the order they appear in the
  file.” The landing policy applies to the static 404 as well. Later
  `! Content-Security-Policy` rules remove it from Flutter responses
  pending spike S3 and replace it with `sandbox` on the cover SVGs.
  API responses use the Worker's own headers. [Workers headers](https://developers.cloudflare.com/workers/static-assets/headers/index.md)
- Cloudflare supports `_redirects` in the static assets directory and
  says “Redirects execute before headers”. Its rules run “regardless of
  whether or not an asset matches the incoming request”, so the Android
  redirect works with a virtual source path.
  [Workers redirects](https://developers.cloudflare.com/workers/static-assets/redirects/index.md)
- `single-page-application` serves the root `index.html` for unknown paths.
  `404-page` returns “a `404 Not Found` response with the nearest
  `404.html`”. The site uses `404-page` because both `/` and `/app/`
  have a directory index. Matching assets are served without invoking
  Worker code (ADR-0014, V4-CACHE-04).
  [Workers static asset routing](https://developers.cloudflare.com/workers/static-assets/#routing-behavior)
