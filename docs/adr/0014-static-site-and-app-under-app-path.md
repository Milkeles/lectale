---
status: accepted
date: 2026-11-21
---

# Static HTML site at `/`, Flutter web app under `/app/` with hash URLs

## Context and problem statement

The owner wants a standard landing page: what Lectale is, download links,
QR codes, log in and create account ([brief](../ux/concepts/2026-11-21-landing-brief.md)).
Today the Worker serves the Flutter web build at `/` and falls back to its
`index.html` for any unknown path (`apps/edge_api/wrangler.jsonc`:
`not_found_handling: "single-page-application"`).

Flutter's own FAQ says Flutter web "is not suitable for static websites with
text-rich flow-based content" and that its output "doesn't align with what
search engines need to properly index". It recommends a separate HTML
landing page. Its accessibility layer is off until a visitor presses a hidden
"Enable accessibility" button
([research note, section 1](../research/2026-11-21-landing-references.md)).
A first-time screen-reader visitor to a Flutter landing page would get
nothing until they found that button.

The site must also make no third-party requests, send a strict
Content-Security-Policy, link into `/app` for sign-in, and carry download
links only to this project's GitHub Releases
([security requirements R16 to R22](../security/reviews/2026-11-21-auth-and-landing-requirements.md)).

## Decision drivers

- Indexing, first load and accessibility of the page a stranger sees first.
- V4-CACHE-04 and ADR-0002: static requests must not run Worker code.
- Free plan: `run_worker_first` requests always invoke the Worker and get a
  429 when the free limit is exceeded
  ([billing page](https://developers.cloudflare.com/workers/static-assets/billing-and-limitations/index.md), fetched 2026-11-21).
- A link to a course must keep working (V4-CORE-01).
- One deployable and no framework for a solo owner.

## Considered options

Where the site lives:

- A. Draw the landing page in Flutter web.
- B. Hand-written static HTML and CSS at `/`, Flutter under `/app/`.
- C. A static-site framework for the landing page.

How `/app/*` reaches the Flutter build (for B):

1. Keep Flutter's default hash URLs: every in-app route is `/app/#/...`.
2. Path URLs, with `/app/*` added to `run_worker_first` and the Worker
   returning `env.ASSETS.fetch("/app/index.html")`.
3. Path URLs with a `_redirects` rule such as `/app/* /app/index.html 200`.

## Decision outcome

Chosen: **B with routing option 1**. The site is static HTML and CSS served
at `/`; the Flutter build lives under `/app/` with `<base href="/app/">`
and keeps hash URLs. The app has no `UrlStrategy` call in `apps/` or
`packages/` (searched 2026-11-21), so this is Flutter's default and needs no
code change.

Why not the others:

- A fails the Flutter FAQ's own guidance and the accessibility problem above.
- C adds a toolchain and dependencies for a handful of pages. No research
  note justifies one.
- Option 2 keeps clean URLs, but every app navigation costs a Worker
  invocation, and the Free plan returns 429 when the limit is hit. The
  reader would stop working while the static site still loads.
- Option 3 does not work as documented. Cloudflare's redirects page says
  "Redirects are always followed, regardless of whether or not an asset
  matches the incoming request", so the rule would also rewrite
  `/app/main.dart.js` to the HTML file
  ([redirects page](https://developers.cloudflare.com/workers/static-assets/redirects/index.md), fetched 2026-11-21).
  I did not test it.

With hash URLs the browser always requests `/app/`, which is a real file, so
no fallback is involved. A course link looks like
`https://<host>/app/#/preview/{repoId}/{sha}`. It deep-links, because the
router reads the fragment (`apps/flutter_client/lib/src/app/router.dart`).
Caching is the asset default for every route, with no Worker involved.

### Site build

- Source is hand-written HTML and CSS in `apps/site/`, with self-hosted
  woff2 fonts and the logo as SVG.
- A small Node script (build time only) writes the QR code SVGs and inlines
  them, writes the download `href`s, and copies the fonts. QR generation
  uses a zero-dependency SVG library from the research note; the pick is
  the implementing task's, under ADR-0010.
- The deploy assembles one directory: the site at its root and the output
  of `flutter build web --base-href /app/` in `app/`. `assets.directory`
  in `wrangler.jsonc` points to that directory.
- This happens in `.github/workflows/deploy-preview.yml`, in the same job
  as the Flutter build and before `wrangler deploy`. `just build-web` gains
  the same assembly step so local runs match.
- `not_found_handling` moves from `single-page-application` to a mode that
  returns a real 404 for unknown URLs. With the SPA mode a mistyped URL
  would return the landing page with status 200. Check the exact mode
  against the Cloudflare page when implementing.
- Headers come from a `_headers` file with two blocks: the landing CSP from
  R18 for `/*`, and the app's CSP for `/app/*` (R19). Cloudflare documents
  `_headers` for static asset responses, which settles the "unverified"
  note in R18. `_headers` does not apply to responses from Worker code, so
  `/api/*` keeps setting its own.

### Native apps

Android, iOS, Linux, Windows and macOS builds never load the site. They
start at the app's `AppRoutes.home` (`router.dart`, `initialLocation`).
Download links on the site point to the GitHub Releases files (R21).

### Consequences

- Good, because the first page is real HTML: indexable, readable by
  assistive technology at once, with link previews and a small first load.
- Good, because it has no Worker invocations on any page or app route.
- Good, because the site has no third-party requests and no script, which
  keeps the policy in R17 and R18 simple.
- Bad, because app URLs contain `#/`. Shared links are longer and the server
  cannot see the course path. Moving to path URLs later means option 2 and
  a new ADR.
- Bad, because the site has no component system; shared header and footer
  are repeated or templated by the build script.
- Bad, because the deploy now has two build outputs to keep in step.
- Changes to existing documents:
  - [`docs/ux/screens/home.md`](../ux/screens/home.md) stops being the
    public front door. It becomes the app's "open by link" entry, reached
    from the landing page's "Use it on the web" and from shared links. Its
    "Entry and exit" table and the "no hero" rule (already withdrawn in the
    brief) need updating when the landing spec is written.
  - `apps/edge_api/wrangler.jsonc` (`assets.directory`,
    `not_found_handling`), `justfile` (`build-web`, `run-web`) and
    `deploy-preview.yml` change in the implementing task.
  - A new screen spec, `docs/ux/screens/landing.md`, and the threat model's
    site rows, follow from the brief and the security review.
  - ADR-0002 stands; only its "serves the Flutter web build" wording
    narrows to `/app/`.

### Confirmation

- A Playwright load of `/` records only the canonical origin and sets no
  cookies (R17).
- A test checks every download `href` against
  `^https://github.com/<owner>/<repo>/releases/` (R21), and CI decodes each
  QR SVG and compares it with the canonical host (R22).
- A request for `/app/`, `/app/main.dart.js` and `/` in a workerd-emulated
  build shows the Worker did not run (V4-CACHE-04).
- Header checks on `/` and `/app/` for the two CSPs and `frame-ancestors 'none'`
  (R16, R18, R19).
- A mistyped URL returns 404, not the landing page.

## More information

- Not verified: how the Flutter service worker and `<base href="/app/">`
  behave with the Cloudflare asset cache after a deploy; measure on the
  first preview deploy.
- Not verified: the exact `not_found_handling` mode name and nested 404
  behaviour (the research note says only the root fallback is documented).
- Revisit if the owner wants path URLs, or a custom domain with a Cloudflare
  Rule that rewrites `/app/*` without Worker billing.
- Related: ADR-0002, ADR-0006, ADR-0010, ADR-0012 (fonts).
