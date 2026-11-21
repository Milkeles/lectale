# Landing concept

Static HTML and CSS for the website and the entry screens. Spec: `../../screens/landing.md`. Screenshots (1440 and 390 px, light and dark, WebP; `index` also at 768 px): `screens/`.

| Task | Command |
|---|---|
| Rebuild the pages | `node build.mjs` |
| Redraw the covers | `python covers.py` (needs `fonttools`, `uharfbuzz`) |
| Redraw the QR code | `QR_MODULE=<path>/node_modules/qr/index.js node make-qr.mjs` |
| Preview | `node serve.mjs 8123`; sends the R18 CSP (`script-src 'none'` except on the catalog); `/app/` shows the open-a-course screen (`app-home-empty.html`) |
| Screenshots and axe | `shoot.mjs` (dev only; needs `playwright-core` and `axe-core` outside the repo) |

`site.css` is the only stylesheet, `catalog.js` the only script (catalog filter; the landing page loads none). Pages are generated, so edit `build.mjs`, not the HTML.

Fonts in `fonts/` are the publishers' own files, unmodified, each with its licence: Source Serif 4 variable (Adobe, `release/WOFF2/VAR`), IBM Plex Sans Regular, Medium and SemiBold, and IBM Plex Mono Regular (`@ibm/plex-sans` 2.0.0 and `@ibm/plex-mono` 2.5.0, `fonts/complete/woff2`, taken from the `npm pack` tarball; the packages' install script sends telemetry, so never `npm install` them).
