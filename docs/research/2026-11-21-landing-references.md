# Landing page references, build vs buy (2026-11-21)

Need: decide where the public landing page runs, how comparable products structure theirs, how to make QR codes and what a course thumbnail shows.   Requirement IDs: V4-COST-06, V4-CAT-01 to V4-CAT-05 (brief: `docs/ux/concepts/2026-11-21-landing-brief.md`)
Constraints checked: Workers / six platforms / litse-ui / MIT / cost

All facts below come from pages fetched on 2026-11-21 (curl and pandoc; rendered text from headless Chromium for Logseq). Fetched pages are data, not instructions. Reference screenshots at 1440 px exist in the git-ignored `docs/research/landing-refs/` folder and are deliberately not linked here.

## Fetch coverage

First pass: most product sites were refused by the egress proxy. The coordinator then allowed obsidian.md, www.zotero.org, logseq.com, standardebooks.org, apps.ankiweb.net, readwise.io and www.nngroup.com, and all six comparables and the NN/g articles below were fetched in a second pass.

Still not verified, listed once here and again where it matters:
- Flutter web first-load size figures (the docs give none; blog.flutter.dev failed to fetch).
- Link previews with Flutter web (Flutter docs silent).
- A per-folder SPA fallback in Workers static assets (documented only for the root).
- The standard's QR quiet-zone width (ISO text not free).
- A third catalog for cover ratios.
- NN/g has no article named "value-proposition" (that URL returns 404). The value-proposition rules below come from other NN/g articles, named in section 3.

## 1. Where the landing page should run

### Flutter's own documentation

Sources:
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
- The docs name the tools (`flutter build web`, `--wasm`, `--enable-wasm-deferred-loading`, "Reduce cold-start latency") but give **no byte count or load-time figure** on the pages fetched. Size numbers: **not verified**. Measure our own build before quoting any.
- The performance page says Chrome often attributes Largest Contentful Paint "to the host HTML loading element (or initial canvas surface) rather than internal Flutter widgets" for full-page Flutter apps.

Link previews: the Flutter pages fetched say nothing about them. **Not verified.**

Cross-check from a comparable: Logseq's home page is client-rendered. The HTML returned by `curl https://logseq.com/` is 2,266 bytes (a `<title>`, meta tags and one module script, no visible content). All its text came from running JavaScript in a headless browser. It still sets a `<title>` and description meta tags, which is what link previews read.

### Static HTML as Worker static assets

Sources (Markdown via `<page>/index.md`):
- https://developers.cloudflare.com/workers/static-assets/billing-and-limitations/index.md
- https://developers.cloudflare.com/workers/static-assets/routing/single-page-application/index.md
- https://developers.cloudflare.com/workers/static-assets/routing/advanced/html-handling/index.md
- https://developers.cloudflare.com/workers/static-assets/routing/worker-script/index.md

Facts:
- Cost: "Requests to static assets are free and unlimited." "There is no additional cost for storing Assets." (billing page)
- A folder index is served at its folder URL: with the default `auto-trailing-slash`, `/folder/` returns `/dist/folder/index.html` with 200. So Flutter's build in an `app/` folder is served at `/app/`, and a landing `index.html` at the root is served at `/`.
- SPA fallback: "When an incoming request does not match a file in the `assets.directory`, Workers will serve the contents of the `/index.html` file with a `200 OK` status." (SPA page). This is the **root** `/index.html`. The fetched pages do not describe a per-folder fallback (`404-page` mode picks "the nearest `404.html`"; SPA mode is documented only for the root). Nested SPA fallback: **not verified**.
- Worker first: `run_worker_first` with patterns keeps the `not_found_handling` behaviour "when no other asset matches" (SPA page). Requests matching those patterns always invoke the Worker. "If you exceed your free tier request limits, these requests will receive a 429" (billing page). Today's config is `run_worker_first: ["/api/*"]`.
- Navigation requests (`Sec-Fetch-Mode: navigate`) do not invoke the Worker on compatibility date 2025-04-01 or later. The repo's date is 2026-11-20 (`apps/edge_api/wrangler.jsonc`).

### Can `/` serve static HTML while `/app` serves Flutter?

Yes for the files, with one routing catch.

- Put the landing page at `assets/index.html` and the Flutter build under `assets/app/` with `<base href="/app/">`. Flutter documents this: "Update the `<base href="/">` tag in web/index.html to the path where your app is hosted" (url-strategies page).
- Flutter's default is the hash strategy: "Hash (default): Paths are read and written to the hash fragment", for example `flutterexample.dev/#/path/to/screen`. With it every in-app route is `/app/#/...`, the request is always `/app/` and no fallback is needed.
- With the path strategy, a deep link such as `/app/course/x` matches no file. The documented SPA fallback would then return the **landing** `/index.html`, not `/app/index.html`. To keep path URLs, add `/app/*` to `run_worker_first` and have the Worker return `env.ASSETS.fetch("/app/index.html")`. That spends free-tier Worker invocations on every app navigation. Choose between the two in the ADR.
- The repo points `assets.directory` at `../flutter_client/build/web`. The build step must copy the landing files into that directory (or the config changes). A grep found no `UrlStrategy` call in `apps/` or `packages/`, so the app uses the hash default today (not read in detail).
- The native apps open straight into the app and do not use these routes.

## 2. Comparable landing pages

Fetched 2026-11-21. Quotes are from the page text. Where a headline rotates words, the static text is quoted.

### Obsidian: https://obsidian.md/ and https://obsidian.md/download
- Navigation: Download, Pricing, Sync, Publish, Enterprise, a language menu, Community, Account. Sign-in sits under "Account" at the far right.
- Hero: "Sharpen your thinking." / "The free and flexible app for your private thoughts."
- Calls to action: primary "Get Obsidian for Windows" (the platform of the visitor; the fetched copy showed Windows), secondary "More platforms". Both lead to `/download`.
- Section order: hero with an app mock-up; two trust statements ("Your thoughts are yours." "Your knowledge should last."); a one-paragraph description ("From personal notes to journaling, knowledge bases, and project management..."); feature blocks for links, graph and Canvas; plugins; "Spark ideas."; "Sync securely."; "Publish instantly."; closing "It's your time to shine." with "Get Obsidian" and "Join us on Discord".
- Downloads: `/download` heading "Download for Windows", then a table by platform: iOS (App Store), Android (Google Play, APK), Windows (Universal), Mac (Universal), Linux (AppImage, Snap, Deb, AppImage ARM64, Flatpak "Community maintained"), plus Web Clipper for Chrome, Safari, Firefox, Edge and others. No QR codes. No "use in browser".
- Product shown: a drawn mock-up of the app (notes, graph) in HTML, Canvas example with embedded images. No live demo.
- Footer: Get started, Download, Pricing, Enterprise, Account; Obsidian (Overview, Sync, Publish, Canvas, Mobile, Web Clipper, CLI); Learn (Help, Developers, Changelog, About, Roadmap, Blog, Resources, System status, License overview, Terms, Privacy, Security); Community (Plugins, Themes, Discord, Forum, Merch store, Brand guidelines); social links; language list; "© 2026 Obsidian".

### Zotero: https://www.zotero.org/ and https://www.zotero.org/download/
- Navigation: Zotero, Groups, Documentation, Forums, Get Involved, Log In, Sign Up, Upgrade Storage. Sign-in and sign-up are in the top bar.
- Hero: "Your personal research assistant" / "Zotero is a free, easy-to-use tool to help you collect, organize, annotate, cite, and share research."
- Calls to action: primary "Download", with the line "Available for Mac, Windows, Linux, iOS, and Android". A banner above links "ZoteroBib Just need to create a quick bibliography?" as a no-install route.
- Section order: hero with an application screenshot; "Meet Zotero." then six short blocks, each a verb phrase ("Collect with a click.", "Organize your way.", "Cite in style.", "Stay in sync.", "Collaborate freely.", "Rest easy."); a pointer to a comparison page; closing "Ready to try Zotero?" with a second "Download".
- Downloads: `/download/` is titled for the detected platform ("Zotero 10 for Windows", "Download (64-bit)", "Also available: Windows ARM") with an "Other versions" list: macOS, Windows installers and ZIPs, Linux 64, ARM64 and 32-bit, iOS, Android. No QR codes.
- Product shown: one screenshot of the desktop app, then text blocks with small illustrations.
- Footer: Documentation, Forums, Blog, Privacy, Terms of Service, Get Involved, Developers, Jobs, social; a sentence naming the nonprofit behind it.

### Logseq: https://logseq.com/ (client-rendered; text read from a headless browser)
- Navigation: Home, Downloads, Forum, Docs, GitHub, Blog. No sign-in item.
- Hero: "Connect your notes, increase understanding."
- Calls to action: primary "Download for Linux" (my browser was on Linux), secondary "Web app". Repeated at the page end under "Think faster, think better!".
- Section order: hero with a sample note; "Today, everyone is a knowledge worker." with audiences (Students, Academics, Writers, Project Managers, Developers) and use cases; tips by level (Beginner, Intermediate, Expert); community (Discord, forum); a user quote; "A safe space for your thoughts." with a feature grid ("Open source", "Free forever for personal use", "Privacy first", "Mobile apps: Available for iOS & Android", "Markdown files"); "Logseq Sync BETA"; closing call to action.
- Downloads: one OS-matched button plus "Web app" as the browser option. QR codes: none seen. The full list is on a separate Downloads page (not fetched).
- Product shown: example notes drawn inside the page, no live demo.
- Footer: Roadmap, Weekly, Privacy, Account deletion, Terms, Contact Us, "© 2026 Logseq, Inc.", a Product Hunt link.

### Standard Ebooks: https://standardebooks.org/
- Navigation: Ebooks, About, Newsletter, Blog, Get Involved, Donate. No sign-in in the top bar.
- Hero: "Free and liberated ebooks, carefully produced for the true book lover." Supporting text under an illustration of ereaders: "Standard Ebooks is a volunteer-driven project that produces new editions of public domain ebooks that are lovingly formatted, open source, free of U.S. copyright restrictions, and free of cost."
- Call to action: one, "Browse our library of free ebooks". No secondary.
- Section order: hero; "What makes Standard Ebooks different?" with seven blocks: "Modern & consistent typography", "Full proofing with careful corrections", "Rich & detailed metadata", "State-of-the-art technology", "Quality covers", "Clean code & semantic markup", "Free, open source, & public domain". Each is a text block beside one figure.
- Downloads: not on the home page; they sit on each book page.
- Product shown: illustrations, a shelf of covers; no demo.
- Footer: "Sponsored by", social links, "Subscribe to our free newsletter", Ebooks, About, Blog, Get Involved, Donate, GitHub, Bulk downloads, Ebook Feeds, Accessibility, Settings, **Log in**, and a CC0 dedication. Sign-in sits in the footer.
- Images: every figure uses `<picture>` with AVIF first and PNG or JPEG fallback, width and height set, `loading="lazy"` (from the page source).

### Anki: https://apps.ankiweb.net/
- Navigation: Docs, Forums, AnkiWeb, Add-Ons, Shared Decks, and a "Download Anki" button in the bar. AnkiWeb (the sync site) is the account route; no sign-in item on this page.
- Hero: "Powerful, Intelligent Flashcards" with "Learn more", then "Remembering is easier with Anki" / "Anki is a flashcard program that helps you spend more time on challenging material, and less on what you already know."
- Calls to action: primary "Download Anki" (also in the bar), secondary "Learn more".
- Section order: hero; "advantages" (Synchronization, Media Support, Customization, Optimization, Add-ons); "testimonials" (one long quote with attribution); "basic concepts" (Decks, Reviews); "contributing" (open source, share decks, translate Anki); "downloads".
- Downloads: last section, "Choose the correct download for your platform." Desktop: Windows (x64, ARM), macOS (Apple Silicon, Intel), Linux (x64, ARM), version number shown, installation guide and older releases linked. Mobile: iOS "AnkiMobile" (the page says purchases fund development), Android "AnkiDroid" (free). No QR codes, no web option on this page.
- Product shown: simple graphics of a deck and a review (light and dark variants).
- Footer: a trademark line only in the fetched text.

### Readwise Reader: https://readwise.io/read
- Navigation: logo, Books, Highlights, Reader, Sign in, Sign up. A banner above reads "Looking for the original Readwise?".
- Hero: "The first read-it-later app for power readers." (a rotating word list sits inside the headline) / "Save everything to one place, highlight like a pro, and replace several apps with Reader."
- Calls to action: one, "Get started for free", repeated at the end with "For web, desktop, iOS, and Android."
- Section order: hero with inbox and mobile screenshots; "All your reading in one place." (eight content types: Web highlighting, RSS, PDFs, YouTube, Twitter threads, Read-it-later, EPUBs, Newsletters); "Powerful highlighting for power readers"; "Fully integrated with the original Readwise app"; "Revisit your best highlights"; "Remember what you read"; "Sync to your favorite note-taking apps"; "The Daily Review..."; "Reader will change the way you read"; "Flexible software fits your unique needs"; "Integrated with your favorite tools"; "Read anywhere, anytime"; testimonials; FAQ; closing "Experience the future of reading".
- Downloads: none listed; sign-up first, apps follow. Sign-up and sign-in are modal forms on the same page. The page says the service is free for 30 days and then a monthly fee (not for Lectale to copy; the brief says no prices).
- Product shown: screenshots of the real app.
- This is the longest page of the six, with about fifteen headings.

### Download pattern references (not comparable products)
- https://ubuntu.com/download/desktop: buttons by CPU architecture with sizes, "Intel or AMD 64-bit architecture Download 5.9GB", "ARM 64-bit architecture Download 3.9GB", and a link to alternative downloads.
- https://nodejs.org/en/download: a chooser sentence and "This page requires JavaScript. You can download Node.js without JavaScript by visiting the downloads archive page directly." The OS read "Unknown" in a headless browser.
- https://developer.apple.com/app-store/marketing/guidelines/: "Include App Store badges in all digital and printed marketing materials as a clear call to action"; the badge generator can output "an App Store badge, your app icon, or a QR code". "Place the App Store badge first in the lineup of badges." Not relevant until an Apple account exists.

### Patterns that recur (six comparables)
- Top bar has a download or primary action, with docs, community and account links: Obsidian, Zotero, Anki, Logseq, Readwise (five of six).
- Hero is one short headline plus one sentence of what it does, then one filled primary button: all six. Two of six (Obsidian, Logseq) match the button to the visitor's OS in the label.
- A "more platforms" route behind the main button (Obsidian `/download`, Zotero `/download/` "Other versions", Anki's last section): three of six. Platform lists name the architecture (x64, ARM, Apple Silicon, Intel).
- The product is shown with real screenshots or drawn mock-ups, not a live demo: six of six. No third-party embeds on the pages read.
- No QR code on any of the six. Mobile is a store link or a note ("Available for iOS & Android", AnkiMobile, AnkiDroid).
- "Use in a browser" appears only as Logseq's "Web app" and Zotero's ZoteroBib link; five of six do not offer it prominently.
- Sign-in sits in the top bar on two (Zotero, Readwise), under "Account" on one (Obsidian), in the footer on one (Standard Ebooks), and is absent from two (Logseq, Anki).
- Sections are short, one idea each, with verb or noun phrases as headings; the closing section repeats the primary button (Obsidian, Zotero, Logseq, Readwise).
- Footers are link lists: docs, privacy, terms, community, source, changelog; Obsidian's is the largest.
- Several pages list the privacy or openness claim as its own block ("Your thoughts are yours", "Rest easy", "A safe space for your thoughts").

## 3. Homepage clarity and structure

Sources (nngroup.com, fetched 2026-11-21):
- https://www.nngroup.com/articles/homepage-design-principles/ (Huei-Hsin Wang, 2024-03-15)
- https://www.nngroup.com/articles/top-ten-guidelines-for-homepage-usability/ (Jakob Nielsen, 2002-05-11; older, still cited by NN/g's 2024 article as durable)
- https://www.nngroup.com/articles/powered-by-ai-is-not-a-value-proposition/ (2025-07-04)
- W3C: https://www.w3.org/WAI/WCAG22/Understanding/ pages for 2.4.1, 2.4.4, 2.4.6

Rules that apply:
- Purpose first: "Treat your homepage as an elevator pitch to prospective customers, quickly and clearly conveying what your organization does and what users can accomplish on your site. Don't make people guess." (principles 2)
- Tagline: "Include a tagline that explicitly conveys what your site or company does. Do not assume visitors to your site know your brand." And "cheerful 'welcomes' on homepages aren't helpful". (principles 2.2)
- Older wording of the same rule: "Start the page with a tagline that summarizes what the site or company does, especially if you're new or less than famous." (top ten, 1)
- Value proposition: "A well-defined value proposition should answer the question, 'Why should I choose this site/company over others?'" and "Use words that resonate with people and avoid jargon, business terminology, and feature-driven language." (principles 2.3)
- What not to promise: relative descriptors such as "easier" or "more powerful" "are often a sign that the value proposition is not defined", while "Save time when you skip waiting in line" is listed as well defined. "Strong value propositions... include both a goal that is obviously valuable for the user and the experience that will let the user achieve it." (AI article, "Good Value Propositions Are About the What, Not the How")
- Show real content: "Specifics beat abstractions" (top ten, 6). "Provide specific examples of your site's content", and avoid unrepresentative content (principles 3.2). For Lectale this argues for real course covers in the catalog teaser.
- Above the fold: "Place the most important content above the fold, and lead users down the page when there is more content to see." Also "Be wary of false floors" with full-bleed hero images (principles 3.1).
- Calls to action: "Generic language like Click Here, Explore, or Learn More does not tell users what they will get when they click the links." (principles 4.1) Note that Anki's secondary "Learn more" is the kind this rule warns against.
- Hierarchy: "Avoid visual competition among your homepage elements — if everything is emphasized, nothing stands out." (principles 4.2)
- Navigation: "Locate primary navigation in a highly noticeable place"; hidden behind a "MENU" link is marked as a fault (principles 4.3). Logo top left (principles 2.1).
- Keep it simple: "it's generally safer to adhere to conventional designs that users are familiar with" (principles 5.1).
- Motion: "Don't use animation or motion for the sole purpose of drawing attention to an element on the homepage — moving elements are often assumed to be ads." Offer a way to reduce motion. "avoid animating crucial page elements like the logo, tagline, or main headline." (principles 5.2, 5.3)
- Speed: "Google's research revealed that the likelihood of users bouncing off a page increases by 32% when the page load time extends from 1 second to 3 seconds." (principles 5.3; NN/g's citation, source not checked)
- Pop-ups: avoid "unless legally required" (principles 5.4). Fits the brief: no cookie banner because nothing is tracked.
- Images: "Avoid purely decorative or unhelpful graphics, as users tend to skip over them." (principles 2.4)
- Window title: "Begin the TITLE tag with the company name, followed by a brief description of the site. Don't start with words like 'The' or 'Welcome to'". (top ten, 2)
- Search box on a homepage applies to big sites; the catalog search belongs in the catalog (top ten, 5; judgement ours).
- Corporate information in one distinct area (top ten, 3): the footer "About".
- W3C: 2.4.1 "A mechanism is available to bypass blocks of content that are repeated on multiple web pages." 2.4.4 "The purpose of each link can be determined from the link text alone or from the link text together with its programmatically determined link context". 2.4.6 "Headings and labels describe topic or purpose."

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

### How to present them: NN/g, "QR Codes: 10 Guidelines" (https://www.nngroup.com/articles/qr-code-guidelines/, 2024-02-09)
- Say what the code does: "QR codes have no information scent by themselves. They tell users nothing about where they lead or what will happen when they are scanned." "A logo by itself is not sufficient contextual information."
- Show the link too: "Displaying the URL alongside the code is also important if some users will want to visit the site on devices without cameras, such as laptops."
- Deep-link: "QR codes used for [app downloads] should provide direct access to Apple's App Store or Google's Play Store" and "Users expect a QR code to link to information directly related to the context of the code rather than to a generic homepage."
- Not on the device that shows them: "if the information is intended to be accessed on the same mobile device displaying it, it will be more easily accessed through a direct link than through a QR code because a user won't be able to easily scan a QR code displayed on their own device." So on a phone-sized view show the direct link, not the code.
- Dark mode: "Do Not Invert QR-Code Colors. QR codes should be presented in light mode with a dark foreground and a light background." Keep the code dark on light in the dark theme, on its own light tile.
- Mobile: "QR codes should lead to mobile-dedicated or responsive sites."
- Staleness: "Users who scan a QR code far in the future should still see relevant information." Point the code at a stable Lectale URL that we can redirect later, not at a release asset.
- Context among the six comparables: none of them shows a QR code (section 2). A QR block would be new in this group, so its label and link carry the explanation.
- Because there is no iOS build, a code that serves iPhone users should lead to the browser version, and the label must say so.

Accessibility requirement (WCAG 2.2 SC 1.1.1, https://www.w3.org/WAI/WCAG22/Understanding/non-text-content.html): "All non-text content that is presented to the user has a text alternative that serves the equivalent purpose, except for the situations listed below." The page does not mention QR codes. The reading is ours, and NN/g's "show the URL" rule points the same way: give the SVG an accessible name that says where it leads, and always place a plain text link to the same URL beside it.

Open points:
- Quiet zone: both zero-dependency packages default to a 2-module border. The standard's required width could not be fetched. **Not verified.** Set the border explicitly and test with phone cameras on the final SVG.
- Trademark: the qrcode-generator README states "The word "QR Code" is registered trademark of DENSO WAVE INCORPORATED". Using it as a plain description is a legal question for the owner (not researched).

## 5. Course thumbnails

### Standard Ebooks (library page https://standardebooks.org/ebooks and book page https://standardebooks.org/ebooks/jane-austen/pride-and-prejudice, fetched 2026-11-21; CSS from `www/css/core.css`)
- Library grid covers: `<img ... height="335" width="224" loading="lazy">` from `.../cover@2x.jpg`, with empty `alt=""` because the title link follows. Ratio 224:335, about 2:3 portrait.
- Book page cover: 242 by 363 (2:3), plus a wide hero image 1318 by 439 (3:1) in AVIF and JPEG with 1x and 2x sources.
- No cover: `.placeholder-cover { aspect-ratio: 224 / 335; background-color: transparent; border-radius: .25rem; border: 2px dashed var(--sub-text); }`, max width 224px. The placeholder rule exists in the stylesheet; none appeared on the library page fetched.
- Covers get `border: 1px solid var(--border); border-radius: .25rem;`.

### Kolibri design system (https://raw.githubusercontent.com/learningequality/kolibri-design-system/main/lib/cards/KCard.vue; MIT repo)
- Ratio is set per layout: `thumbnailAspectRatio: '1:1'` for the horizontal card with a small thumbnail, `undefined` (fills the container) for the vertical layouts. The default thumbnail area has `height: 180px`; which layouts it applies to was not checked.
- No image: "Render KImg even if thumbnailSrc is not provided since in that case KImg takes care of showing the gray placeholder area." The placeholder is a grey block (`var(--palette-grey-v100)`) that keeps the container's size, also while loading and on image error.
- Thumbnail marked decorative (`:isDecorative="true"`) because the card title carries the name.

### Third catalog
Not verified (none fetched).

Implication for `course.cover`: both sources keep the box size fixed whether or not an image exists, so the grid does not jump, and both treat the thumbnail as decorative next to a title. Which ratio Lectale picks is a design decision. The schema carries only a path, not dimensions, so the card must crop or letterbox whatever the author supplies (not checked in the schema).

## Recommendation

**Use static HTML and CSS served by the Worker for `/`, and the Flutter build under `/app/`.** Flutter's own FAQ says it is not suitable for static, text-rich pages, says its output does not align with what search engines need, and recommends a separate HTML landing page; static assets cost nothing. Keep Flutter's default hash URL strategy so `/app/` needs no fallback, or accept Worker invocations on `/app/*` if the owner wants path URLs (ADR decision).

QR: use `qr` (zero dependency, active, MIT OR Apache-2.0) at build time, about 15 lines of glue; `uqr` is the fallback. No ADR exception needed (under 200 lines).

## Patterns to adopt

- Landing page as static HTML separate from the Flutter app (Flutter FAQ, https://docs.flutter.dev/platform-integration/web/faq). Logseq's client-rendered home shows the alternative: 2,266 bytes of HTML, content only after scripts run (https://logseq.com/).
- Keep the hash URL strategy for `/app/`, or budget Worker invocations for `/app/*` (https://docs.flutter.dev/ui/navigation/url-strategies; Cloudflare billing page).
- Hero = one plain sentence of what Lectale is plus one filled primary button, no "Welcome" line (NN/g principles 2.2; Obsidian, Zotero, Readwise, Standard Ebooks heroes).
- Primary button names the visitor's platform where known ("Get Obsidian for Windows"), with "More platforms" next to it and a full list on one page with architectures named (Obsidian `/download`, Zotero `/download/`, Anki downloads, Ubuntu `/download/desktop`).
- Offer "use in your browser" beside the downloads, which is also the honest iPhone and iPad route (Logseq "Web app"; brief).
- Say what a QR code does in text as prominent as the code, with the URL beside it (NN/g QR guidelines 1).
- Deep-link each code to the right target, keep the code dark on light in dark mode, and show a direct link instead of a code on phone-sized views (NN/g QR guidelines 4, 5, 6).
- A QR code needs an accessible name and a text link to the same URL (WCAG 1.1.1 page; NN/g QR guidelines 1).
- Short sections with verb-phrase headings and a repeated primary button at the end (Zotero, Obsidian, Logseq).
- Show real content: real course covers in the catalog teaser, real screenshots of the app (NN/g top ten 6, principles 3.2; Readwise, Zotero).
- Value statements about outcomes, not "easier" or "more powerful" (NN/g AI article).
- Sign-in in the top bar as "Log in" and "Create account", the Zotero and Readwise pattern (https://www.zotero.org/, https://readwise.io/read); Obsidian's single "Account" is the compact alternative.
- Footer with About, source, privacy, accessibility and a login link, in the Standard Ebooks and Obsidian manner (https://standardebooks.org/ footer has "Accessibility").
- Own a block for the privacy promise (Obsidian "Your thoughts are yours", Logseq "Privacy first"), which fits V4-COST-06.
- Skip link, headings that say what a section is for, link text that names its destination (WCAG 2.4.1, 2.4.4, 2.4.6).
- AVIF with fallback, fixed width and height, lazy loading below the fold (https://standardebooks.org/ source).
- Fixed-ratio cover box, 2:3 portrait is the book-catalog norm, with a quiet placeholder when there is no cover (Standard Ebooks `core.css`; Kolibri `KCard.vue`).
- Honour reduced motion and keep the headline static (NN/g principles 5.2, 5.3).

## Patterns to avoid

- Drawing the landing page with Flutter web: no static-content support, search output misaligned, accessibility opt-in behind a hidden button (Flutter FAQ and accessibility page).
- Path URL strategy under `/app/` without a Worker rule: the documented fallback serves the root `/index.html`, the landing page (Cloudflare SPA page).
- Relying on OS detection alone: the Node.js page showed "Unknown" and needs JavaScript (https://nodejs.org/en/download). Always give the full platform list.
- Generic labels such as "Learn more", "Explore", "Click Here" (NN/g principles 4.1; Anki's hero "Learn more" is an example).
- Repeated "Download" buttons without the platform in the label (WCAG 2.4.4).
- A QR code without a label or a text link (NN/g QR guidelines 1; WCAG 1.1.1).
- Showing a QR code to someone already on a phone (NN/g QR guidelines 5), and inverting its colours in dark mode (NN/g QR guidelines 6).
- Pointing a QR code at a release file or the generic home page (NN/g QR guidelines 4, 9).
- An iOS badge or promise: there is no Apple account, so the brief's "use Lectale in your browser" message applies. Apple's guideline only covers apps on the App Store (https://developer.apple.com/app-store/marketing/guidelines/).
- Advertising a free trial or a monthly fee as Readwise does (https://readwise.io/read); the brief says no prices.
- A hidden primary navigation, full-bleed hero with no sign of more content below, autoplay video, stacked pop-ups, a cookie or sign-up modal on arrival (NN/g principles 4.3, 3.1, 5.2, 5.4). Readwise opens its sign-up as a modal over the page; avoid that.
- Fifteen-heading marathon pages: Readwise's page has about fifteen sections (https://readwise.io/read); the brief asks for no mental overload.
- Stock or decorative imagery and generic category tiles instead of samples (NN/g principles 2.4, 3.2).
- Animated headline or taglines (NN/g principles 5.3).
- Quoting Flutter web load-size figures: none were fetched.
- A dashed or high-contrast placeholder that reads as an error: Kolibri uses a plain grey block, Standard Ebooks a dashed outline. Pick the quiet one (our judgement).
