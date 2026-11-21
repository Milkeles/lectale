# Landing concept

Static HTML and CSS for the website and the entry screens. Spec: `../../screens/landing.md`. Screenshots (1440 and 390 px, light and dark, WebP): `screens/`.

| Task | Command |
|---|---|
| Rebuild the pages | `node build.mjs` (`HOOK=D node build.mjs` makes Hook D the default) |
| Redraw the covers | `python covers.py` (needs `fonttools`, `uharfbuzz`) |
| Redraw the QR code | `QR_MODULE=<path>/node_modules/qr/index.js node make-qr.mjs` |
| Preview | `node serve.mjs 8123`; sends the R18 CSP; `/app/` shows the signed-in home mock |
| Screenshots and axe | `shoot.mjs` (dev only; needs `playwright-core` and `axe-core` outside the repo) |

`site.css` is the only stylesheet, `catalog.js` the only script (catalog filter; the landing page loads none). Fonts are woff2 conversions of the app's Source Serif 4 and IBM Plex files, unmodified. Pages are generated, so edit `build.mjs`, not the HTML.
