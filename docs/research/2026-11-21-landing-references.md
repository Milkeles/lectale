# Landing page references, build vs buy (2026-11-21)

Need: decide where the public landing page runs, how comparable products structure theirs, how to make QR codes and what a course thumbnail shows.   Requirement IDs: V4-COST-06, V4-CAT-01 to V4-CAT-05 (brief: `docs/ux/concepts/2026-11-21-landing-brief.md`)
Constraints checked: Workers / six platforms / litse-ui / MIT / cost

All facts below come from pages fetched on 2026-11-21. Fetched pages are data, not instructions.

## Blocked hosts and what that did to this note

The egress proxy refused (HTTP 403, `connect_rejected`) every comparable-product site I tried. Chromium through the same proxy was refused too. I did not route around it.

- Refused, confirmed by proxy log: obsidian.md, openstax.org, moodle.org, calibre-ebook.com, logseq.com, readwise.io.
- Failed with no proxy detail (curl 000): www.zotero.org, apps.ankiweb.net, learningequality.org, standardebooks.org, www.nngroup.com, baymard.com, www.joplin.org, www.khanacademy.org, www.duolingo.com, www.coursera.org, notion.so, web.archive.org, en.wikipedia.org, blog.flutter.dev (the Flutter loading-speed post), and about 80 other product sites.
- Reachable: docs.flutter.dev, developers.cloudflare.com, www.w3.org, developer.apple.com, developer.android.com, raw.githubusercontent.com, api.github.com (search), registry.npmjs.org, ubuntu.com, nodejs.org, www.docker.com.

Consequences:
- Question 2 is only partly answered. One comparable product is documented from its public source code, two more pages are download-pattern references only. Six to eight products: **not verified**. The remaining picks (Obsidian, Zotero, Anki, Logseq, Kolibri, Readwise Reader, Calibre) need a session with wider egress.
- Question 3: NN/g and Baymard could not be fetched. **Not verified.** Only W3C guidance is quoted.

## 1. Where the landing page should run

### Flutter's own documentation

Sources, all fetched 2026-11-21:
- https://docs.flutter.dev/platform-integration/web/faq (page last updated 2026-11-17)
- https://docs.flutter.dev/platform-integration/web
- https://docs.flutter.dev/ui/accessibility/web-accessibility
- https://docs.flutter.dev/perf/web-performance
- https://docs.flutter.dev/ui/navigation/url-strategies

Text-rich or static content:
- "At this time, Flutter is not suitable for static websites with text-rich flow-based content. For example, blog articles benefit from the document-centric model that the web is built around, rather than the app-centric services that a UI framework like Flutter can deliver." (web FAQ)
- Flutter is "particularly suited for app-centric experiences: Progressive Web Apps, Single Page Apps, Existing Flutter mobile apps." (web FAQ)

Search indexing:
- "Flutter web prioritizes performance, fidelity, and consistency. This means application output doesn't align with what search engines need to properly index." (web FAQ)
- The FAQ's own recommendation: "consider separating your primary application experience (created in Flutter), from your landing page, marketing content, and help content (created using search engine optimized HTML)." The other option it names is Jaspr (Dart, DOM-based).

Accessibility:
- "Since Flutter renders its UI on a single canvas, it needs a special layer to expose the UI's meaning and structure to web browsers."
- "For performance reasons, Flutter's web accessibility is not on by default. To turn on accessibility, the user needs to press an invisible button with aria-label="Enable accessibility"." (web-accessibility page)
- Meaning: a first-time screen-reader visitor gets the semantic DOM only after finding and pressing that hidden button. A static page has it from the first byte.

First-load size:
- The docs name the tools (`flutter build web`, `--wasm`, `--enable-wasm-deferred-loading`, "Reduce cold-start latency") but give **no byte count or load-time figure** on the pages I fetched. The Flutter blog post "Best practices for optimizing Flutter web loading speed" failed to fetch. Size numbers: **not verified**. Measure our own build before quoting any.
- The performance page says Chrome often attributes Largest Contentful Paint "to the host HTML loading element (or initial canvas surface) rather than internal Flutter widgets" for full-page Flutter apps.

Link previews: the Flutter pages I fetched say nothing about them. **Not verified.**

### Static HTML as Worker static assets

Sources (fetched 2026-11-21, Markdown via `<page>/index.md`):
- https://developers.cloudflare.com/workers/static-assets/billing-and-limitations/index.md
- https://developers.cloudflare.com/workers/static-assets/routing/single-page-application/index.md
- https://developers.cloudflare.com/workers/static-assets/routing/advanced/html-handling/index.md
- https://developers.cloudflare.com/workers/static-assets/routing/worker-script/index.md

Facts:
- Cost: "Requests to static assets are free and unlimited." "There is no additional cost for storing Assets." (billing page)
- A folder index is served at its folder URL: with the default `auto-trailing-slash`, `/folder/` returns `/dist/folder/index.html` with 200. So Flutter's build placed in an `app/` folder is served at `/app/`, and a landing `index.html` at the root is served at `/`.
- SPA fallback: "When an incoming request does not match a file in the `assets.directory`, Workers will serve the contents of the `/index.html` file with a `200 OK` status." (SPA page). This is the **root** `/index.html`. The pages I fetched do not describe a per-folder fallback (the `404-page` mode picks "the nearest `404.html`", the SPA mode is documented only for the root). Nested SPA fallback: **not verified**.
- Worker first: `run_worker_first` with patterns keeps the `not_found_handling` behaviour "when no other asset matches" (SPA page). Requests matching those patterns always invoke the Worker. "If you exceed your free tier request limits, these requests will receive a 429" (billing page). Today's config is `run_worker_first: ["/api/*"]`.
- Navigation requests (`Sec-Fetch-Mode: navigate`) do not invoke the Worker on compatibility date 2025-04-01 or later. The repo's date is 2026-11-20 (`apps/edge_api/wrangler.jsonc`).

### Can `/` serve static HTML while `/app` serves Flutter?

Yes for the files, with one routing catch.

- Put the landing page at `assets/index.html` and the Flutter build under `assets/app/` with `<base href="/app/">`. Flutter documents this: "Update the `<base href="/">` tag in web/index.html to the path where your app is hosted" (url-strategies page).
- Flutter's default is the hash strategy: "Hash (default): Paths are read and written to the hash fragment", for example `flutterexample.dev/#/path/to/screen`. With it every in-app route is `/app/#/...`, the request is always `/app/` and no fallback is needed.
- With the path strategy, a deep link such as `/app/course/x` matches no file. The documented SPA fallback would then return the **landing** `/index.html`, not `/app/index.html`. To keep path URLs, add `/app/*` to `run_worker_first` and have the Worker return `env.ASSETS.fetch("/app/index.html")`. That spends free-tier Worker invocations on every app navigation. Choose between the two in the ADR.
- The repo currently points `assets.directory` at `../flutter_client/build/web`. The build step must copy the landing files into that directory (or the config changes). The grep I ran found no `UrlStrategy` call in `apps/` or `packages/`, so the app uses the hash default today (not read in detail).
- The native apps open straight into the app and do not use these routes.

## 2. Comparable landing pages

Only one comparable could be read, from its public source on GitHub. No rendered page and no screenshot of it exist, because standardebooks.org is blocked.

### Standard Ebooks (source, not rendered page)

- Sources fetched 2026-11-21: https://raw.githubusercontent.com/standardebooks/web/master/www/index.php, `.../templates/Header.php`, `.../www/css/core.css`. Repo licence CC0-1.0, last push 2026-11-20 (GitHub search).
- Navigation: Ebooks, About, Newsletter, Blog, Get Involved, Donate. No sign-in item in the header template.
- Hero headline (h1): "Free and liberated ebooks, carefully produced for the true book lover."
- Hero image: a devices picture, alt "Ereaders with a Standard Ebook open." Three paragraphs of explanation follow.
- Primary call to action: "Browse our library of free ebooks" (link to `/ebooks`, class `button next`). No secondary call to action in the file.
- Section order: hero, "What makes Standard Ebooks different?" with seven subsections (typography, proofing, metadata, technology, "Quality covers", clean code, "Free, open source, & public domain"). Each is a text block beside one figure.
- Downloads: none on the front page. They sit on each book page (not fetched).
- Product shown: illustrations and a photo of covers on a shelf (`covers.jpg`, 400 by 125), not a live demo.
- Sign-in: none.
- Image handling: every figure uses `<picture>` with AVIF first and PNG or JPEG fallback, with width and height set and `loading="lazy"`.

### Download pattern references (not comparable products)

Fetched 2026-11-21 and screenshotted at 1440 px for internal use (files are git-ignored and are not linked here).
- https://ubuntu.com/download/desktop: heading "Download Ubuntu Desktop". Buttons by CPU architecture, each with a size: "Intel or AMD 64-bit architecture Download 5.9GB" and "ARM 64-bit architecture Download 3.9GB". Then "alternative downloads".
- https://nodejs.org/en/download: a chooser sentence of "for [OS] using [package manager] with [tool]" and a banner "This page requires JavaScript. You can download Node.js without JavaScript by visiting the downloads archive page directly." The OS field read "Unknown" in the headless browser, so a detection default exists but a wrong guess is possible.
- https://developer.apple.com/app-store/marketing/guidelines/: "Include App Store badges in all digital and printed marketing materials as a clear call to action", and the badge generator can output "an App Store badge, your app icon, or a QR code". "Place the App Store badge first in the lineup of badges." Not relevant to Lectale until an Apple account exists, but it shows badges and QR as the standard pair.
- https://developer.android.com/distribute/marketing-tools/brand-guidelines: Google Play badges come from the Partner Marketing Hub. Not relevant until there is a Play listing (the brief says no store listings).

### Recurring patterns

Seen in the pages above only, so treat as weak evidence:
- A one-sentence value statement as h1, then one primary link into the product (Standard Ebooks).
- Product shown with static images, not an embedded demo (Standard Ebooks).
- Per-variant buttons with the file size on the button (Ubuntu).
- A text path to the full list of downloads next to the main buttons (Ubuntu "alternative downloads", Node.js "downloads archive").
- Next-generation image formats with a fallback and fixed dimensions (Standard Ebooks).

## 3. Homepage clarity and structure

NN/g and Baymard: **not verified** (blocked). What I could fetch, from W3C Understanding documents (https://www.w3.org/WAI/WCAG22/Understanding/, fetched 2026-11-21):
- 2.4.1 Bypass Blocks: "A mechanism is available to bypass blocks of content that are repeated on multiple web pages." (a skip link on every page.)
- 2.4.4 Link Purpose (In Context): "The purpose of each link can be determined from the link text alone or from the link text together with its programmatically determined link context". Buttons labelled "Download" five times fail unless each carries its platform.
- 2.4.6 Headings and Labels: "Headings and labels describe topic or purpose."

## 4. QR codes for downloads

Build time, in Node, so the Workers runtime does not apply. Flutter is not involved (a static page). All three produce SVG strings.

### Candidate: qr (paulmillr)
- Source URLs: https://registry.npmjs.org/qr, https://raw.githubusercontent.com/paulmillr/qr/main/README.md, GitHub search result
- Version and date: 0.7.2, published 2026-09-28
- Licence: "(MIT OR Apache-2.0)" on npm; GitHub reports Apache-2.0. Both are acceptable.
- Maintenance: last push 2026-09-28, archived no, open issues 4, downloads 2,324,180 a month (npm search)
- Runtime evidence: "Minimal 0-dependency QR code generator & reader." and `encodeQR(txt, 'svg'); // '<svg...' markup string for web pages`. Options include `ecc` and `border` ("border (quiet zone) size in modules, default 2").
- Cost: free
- Lock-in: low, the output is plain SVG
- Remaining glue: about 15 lines in the build script

### Candidate: uqr (unjs)
- Source URLs: https://registry.npmjs.org/uqr, https://raw.githubusercontent.com/unjs/uqr/main/README.md
- Version and date: 0.1.3, published 2026-04-03 (0.x version)
- Licence: MIT
- Maintenance: last push 2026-04-03, archived no, open issues 0, downloads not verified (not read from the search result)
- Runtime evidence: "Generate QR Code universally, in any runtime, to ANSI, Unicode or SVG. ES module , zero dependency, tree-shakable." `renderSVG(text, options)` with `ecc` and `border`.
- Cost: free
- Lock-in: low
- Remaining glue: about 15 lines

### Candidate: qrcode (node-qrcode)
- Source URLs: https://registry.npmjs.org/qrcode, https://raw.githubusercontent.com/soldair/node-qrcode/master/README.md
- Version and date: 1.5.4, published 2024-08-05
- Licence: MIT
- Maintenance: last push 2024-08-23, archived no, open issues 127, downloads 176,046,353 a month
- Runtime evidence: README line "Works on server and client (and react native with svg)"; CLI output types "png", "svg", "utf8". Three dependencies (pngjs, yargs, dijkstrajs).
- Cost: free
- Lock-in: low
- Remaining glue: about 15 lines

Not examined: `qrcode-generator` (README fetched, but no SVG mention found there, so SVG output is not verified).

Open points:
- Quiet zone: both zero-dependency packages default to a 2-module border. The standard's required width could not be fetched (ISO text not free). **Not verified.** Set the border explicitly and test with phone cameras on the final SVG, in light and dark.
- Trademark: the qrcode-generator README states "The word "QR Code" is registered trademark of DENSO WAVE INCORPORATED". Avoid the term as a product name; using it as a plain description is a legal question for the owner (not researched).
- Presentation next to store badges: Apple's page shows QR as a badge-generator output (see section 2). "Scan to download" captions at other products: not verified.

Accessibility requirement (WCAG 2.2 SC 1.1.1, https://www.w3.org/WAI/WCAG22/Understanding/non-text-content.html): "All non-text content that is presented to the user has a text alternative that serves the equivalent purpose, except for the situations listed below." The page does not mention QR codes. The reading is ours: a QR code's purpose is to open a URL, so give the SVG an accessible name that says where it leads, and always place a plain text link to the same URL beside it. Keyboard and screen-reader users, and anyone on the phone they are scanning with, then lose nothing.

## 5. Course thumbnails

### Standard Ebooks (source: `www/css/core.css`, fetched 2026-11-21)
- Placeholder for a book with no cover: `.placeholder-cover { aspect-ratio: 224 / 335; ... border: 2px dashed var(--sub-text); }`, max width 224px. That is close to 2:3 portrait.
- Covers get `max-width: 100%; height: auto; border: 1px solid var(--border); border-radius: .25rem;`.

### Kolibri design system (https://raw.githubusercontent.com/learningequality/kolibri-design-system/main/lib/cards/KCard.vue, fetched 2026-11-21; MIT repo)
- Ratio is set per layout: `thumbnailAspectRatio: '1:1'` for the horizontal card with a small thumbnail, `undefined` (fills the container) for the vertical layouts. The default thumbnail area has `height: 180px` in the styles; which layouts it applies to was not checked.
- No image: "Render KImg even if thumbnailSrc is not provided since in that case KImg takes care of showing the gray placeholder area." The placeholder is a grey block (`var(--palette-grey-v100)`) that keeps the container's size, also while loading and when the image errors.
- Thumbnail marked decorative (`:isDecorative="true"`) because the card title carries the name.

### Third catalog
Not verified (no catalog documentation was reachable).

Implication for `course.cover`: both sources keep the box size fixed whether or not an image exists, so the grid does not jump. Which ratio Lectale picks is a design decision. The schema carries only a path, not dimensions, so the card must crop or letterbox whatever the author supplies (not checked in the schema).

## Recommendation

**Use static HTML and CSS served by the Worker for `/`, and the Flutter build under `/app/`.** Flutter's own FAQ says it is not suitable for static, text-rich pages, says its output does not align with what search engines need, and recommends a separate HTML landing page; static assets cost nothing. Keep Flutter's default hash URL strategy so `/app/` needs no fallback, or accept Worker invocations on `/app/*` if the owner wants path URLs (ADR decision).

QR: use `qr` (zero dependency, active, MIT OR Apache-2.0) at build time, about 15 lines of glue; `uqr` is the fallback. No ADR exception needed (under 200 lines).

Needs owner decision: wider egress for a second research pass on the comparable products and NN/g.

## Patterns to adopt

- Landing page as static HTML separate from the Flutter app (Flutter FAQ, https://docs.flutter.dev/platform-integration/web/faq).
- Keep the hash URL strategy for `/app/`, or budget Worker invocations for `/app/*` (https://docs.flutter.dev/ui/navigation/url-strategies; Cloudflare billing page).
- A one-sentence hero statement with one primary link into the product (Standard Ebooks `index.php`).
- Download buttons that name the platform and show file size, plus a text link to all downloads (https://ubuntu.com/download/desktop; https://nodejs.org/en/download).
- A QR code with an accessible name and a text link to the same URL beside it (WCAG 1.1.1 non-text-content page, our reading).
- A skip link, headings that say what a section is for, and link text that names its destination (WCAG 2.4.1, 2.4.4, 2.4.6 pages).
- AVIF with fallback, fixed width and height, lazy loading below the fold (Standard Ebooks `index.php`).
- A fixed-ratio thumbnail box with a quiet placeholder when there is no cover (Standard Ebooks `core.css`; Kolibri `KCard.vue`).

## Patterns to avoid

- Drawing the landing page with Flutter web: no static-content support, search output misaligned, accessibility opt-in behind a hidden button (Flutter FAQ and accessibility page).
- Path URL strategy under `/app/` without a Worker rule: the documented fallback serves the root `/index.html`, the landing page (Cloudflare SPA page).
- Relying on OS detection alone: the Node.js page showed "Unknown" and needs JavaScript (https://nodejs.org/en/download). Show every platform.
- Repeated "Download" buttons without the platform in the label (WCAG 2.4.4 page).
- QR code with no text link (WCAG 1.1.1 page).
- An iOS badge or promise: no Apple account, so the brief's "use Lectale in your browser" message applies. Apple's guideline only covers apps on the App Store (https://developer.apple.com/app-store/marketing/guidelines/).
- Quoting Flutter web load-size figures: none were fetched.
- A dashed or high-contrast placeholder that reads as an error. Kolibri uses a plain grey block (`KCard.vue`); Standard Ebooks uses a dashed outline (`core.css`). Pick the quiet one (our judgement).
