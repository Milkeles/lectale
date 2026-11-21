# Commands

Flutter is pinned by mise (3.50.1). Run from the repository root; the app is `apps/flutter_client`.

## Build and serve the web app

```sh
cd apps/flutter_client
flutter build web --release
python3 -m http.server 8080 --directory build/web &
SERVER=$!
# ... capture ...
kill $SERVER
```

The Python server is enough for review. Production headers (CSP, cache classes) are tested separately.

## Capture with Playwright (Node)

Chromium is preinstalled; `PLAYWRIGHT_BROWSERS_PATH` points at it. Save as `tool/shots.mjs` and run `node tool/shots.mjs http://localhost:8080 shots home`.

```js
import { chromium } from 'playwright';
const [base, out, name] = process.argv.slice(2);
const browser = await chromium.launch();
for (const width of [360, 768, 1440]) {
  for (const scheme of ['light', 'dark']) {
    const ctx = await browser.newContext({
      viewport: { width, height: width < 700 ? 800 : 900 },
      deviceScaleFactor: 1,
      colorScheme: scheme,
    });
    const page = await ctx.newPage();
    await page.goto(base);
    await page.waitForTimeout(1500); // first frame of the canvas
    await page.screenshot({ path: `${out}/${name}-${width}-${scheme}.png` });
    await page.keyboard.press('Tab');
    await page.screenshot({ path: `${out}/${name}-${width}-${scheme}-focus.png` });
    await ctx.close();
  }
}
await browser.close();
```

Python equivalent: `from playwright.sync_api import sync_playwright`, then `browser.new_context(viewport={...}, device_scale_factor=1, color_scheme=scheme)`. If the app ignores `prefers-color-scheme`, use its own theme switch instead.

For other routes, loop over them with `page.goto(base + route)`. Use a scale factor of 2 only for images shared with someone else.

## Goldens (native layouts)

```sh
flutter test --update-goldens --tags golden   # Linux only
git status --short '*.png'                    # then view each changed image
```

## Codex second opinion

```sh
codex exec --sandbox read-only -i shots/home-360-light.png -i shots/home-1440-dark.png "<prompt>"
```

`-i` takes one or more image files; `--sandbox read-only` stops Codex editing the repository. Codex needs a device-code login in each new container.
