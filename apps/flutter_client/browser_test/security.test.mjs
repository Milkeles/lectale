// Browser-level check of the trust boundary, against the real /app/ web build.
//
// It opens a fixture course whose README tries to reach a tracker, climb out
// of the repository and load a malformed path, records every request the
// page makes, and checks that nothing but the pinned course is contacted and
// that the valid relative image loads through the files route.
//
// Run (needs the build and Playwright; the sandbox has no route to gstatic,
// so CanvasKit is served from the build):
//   cd apps/flutter_client
//   flutter build web --release --base-href /app/
//   NODE_PATH=/opt/node22/lib/node_modules CHROME=/usr/bin/google-chrome \
//     node --test browser_test/security.test.mjs
import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { after, before, test } from 'node:test';
import { fileURLToPath, pathToFileURL } from 'node:url';

import { BASE, REPO_ID, SHA, startFixture } from './fixture_server.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const webDir = resolve(process.env.WEB ?? join(here, '..', 'build', 'web'));
const playwrightPath = process.env.PLAYWRIGHT
  ?? '/opt/node22/lib/node_modules/playwright/index.mjs';

let browser;
let fixture;

before(async () => {
  assert.ok(existsSync(join(webDir, 'index.html')), `build the web app first: ${webDir}`);
  const { chromium } = await import(pathToFileURL(playwrightPath).href);
  browser = await chromium.launch({ executablePath: process.env.CHROME });
  fixture = await startFixture({ webDir });
});

after(async () => {
  await browser?.close();
  fixture?.server.close();
});

/** Opens [route] and returns every request the page made, by origin. */
async function openAndRecord(route, { scheme = 'light', width = 1440 } = {}) {
  const context = await browser.newContext({
    viewport: { width, height: 900 },
    colorScheme: scheme,
  });
  const seen = [];
  const origin = fixture.origin;
  // CanvasKit comes from the build, not the CDN; everything else that leaves
  // the fixture origin is recorded and refused.
  await context.route('**/*', (r) => {
    const url = new URL(r.request().url());
    if (url.origin === origin) return r.continue();
    if (url.host === 'www.gstatic.com' && url.pathname.includes('/flutter-canvaskit/')) {
      const rel = url.pathname.replace(/^\/flutter-canvaskit\/[^/]+\//, '');
      const file = join(webDir, 'canvaskit', rel);
      if (existsSync(file)) {
        return r.fulfill({
          body: readFileSync(file),
          contentType: file.endsWith('.wasm') ? 'application/wasm' : 'text/javascript',
        });
      }
    }
    seen.push({ origin: url.origin, host: url.host, url: url.href });
    return r.abort();
  });
  const page = await context.newPage();
  page.on('request', (r) => {
    const url = new URL(r.url());
    if (url.origin === origin) seen.push({ origin: url.origin, host: url.host, url: url.href });
  });
  await page.goto(origin + route);
  await page.reload();
  await page.waitForTimeout(5000);
  return { page, context, seen };
}

// The Flutter engine itself fetches its fallback font from this host; it is
// not course content, and nothing a course says can change it.
const engineHosts = new Set(['fonts.gstatic.com']);
const foreignOf = (seen) =>
  seen.filter((r) => r.origin !== fixture.origin && !engineHosts.has(r.host));

const course = `/app/#/preview/${REPO_ID}/${SHA}`;

test('the README reaches no other host and loads only its valid image', async () => {
  const { context, seen } = await openAndRecord(course);
  try {
    const foreign = foreignOf(seen);
    assert.deepEqual(foreign, [], `requests to other hosts: ${JSON.stringify(foreign)}`);
    assert.equal(seen.filter((r) => r.host === 'tracker.example').length, 0);

    // Nothing was asked for with a climb, an encoding of one or a bad escape.
    const paths = seen.map((r) => new URL(r.url).pathname + new URL(r.url).search);
    for (const path of paths) {
      assert.doesNotMatch(path, /secret/i, `unexpected path ${path}`);
      assert.doesNotMatch(path, /%2e|\.\./i, `unexpected path ${path}`);
      assert.doesNotMatch(path, /%ff/i, `unexpected path ${path}`);
    }

    // Every API request is inside the pinned course.
    const api = paths.filter((p) => p.startsWith('/api/'));
    assert.ok(api.length > 0, 'the course loaded');
    for (const path of api) {
      assert.ok(path.startsWith(`${BASE}`), `request outside the pinned course: ${path}`);
    }

    // The valid relative image: exactly one request, same origin, with this
    // repository ID and commit, through the files route.
    const images = seen.filter((r) => r.url.endsWith('/figures/histogram.png'));
    assert.equal(images.length, 1, `histogram requests: ${JSON.stringify(images)}`);
    assert.equal(images[0].url, `${fixture.origin}${BASE}/files/figures/histogram.png`);
  } finally {
    await context.close();
  }
});

test('opening the lesson loads its own relative image the same way', async () => {
  const { context, seen } = await openAndRecord(`${course}/one/notes`);
  try {
    assert.deepEqual(foreignOf(seen), []);
    const images = seen.filter((r) => r.url.endsWith('/figures/histogram.png'));
    assert.equal(images.length, 1);
    assert.equal(images[0].url, `${fixture.origin}${BASE}/files/figures/histogram.png`);
  } finally {
    await context.close();
  }
});

test('a bad deep link goes to /open and requests nothing from the course', async () => {
  const before = fixture.requests.length;
  const { page, context, seen } = await openAndRecord('/app/#/preview/abc/xyz');
  try {
    assert.match(page.url(), /#\/open$/);
    assert.deepEqual(foreignOf(seen), []);
    const after = fixture.requests.slice(before).filter((r) => r.includes('/api/'));
    assert.deepEqual(after, []);
  } finally {
    await context.close();
  }
});
