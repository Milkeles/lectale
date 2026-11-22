// The hero's quote cards circle the book on a CSS motion path. Whatever the
// phase of the lap, a card must stay inside the content column and must never
// cover the headline, the lead, the buttons or the pause button.
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { createServer } from 'node:http';
import { createRequire } from 'node:module';
import { extname } from 'node:path';
import { after, before, describe, test } from 'node:test';
import { fileURLToPath } from 'node:url';

const { chromium } = createRequire(import.meta.url)('playwright');

const dist = fileURLToPath(new URL('../dist/', import.meta.url));
const types = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css',
  '.js': 'text/javascript',
  '.svg': 'image/svg+xml',
  '.webp': 'image/webp',
  '.avif': 'image/avif',
  '.woff2': 'font/woff2',
};
const widths = [1440, 1280, 1024, 768];
const LAP = 72; // seconds, `--orbit-lap`
const STEPS = 24;
// Two cards trade places every second lap, so the lap is sampled twice: once
// for each half of the swap.
const times = Array.from({ length: 2 * STEPS }, (_, i) => (i * LAP) / STEPS);

let server;
let browser;
let origin;

before(async () => {
  server = createServer(async (req, res) => {
    const path = new URL(req.url, 'http://localhost').pathname;
    const file = path.endsWith('/') ? `${path}index.html` : path;
    try {
      const body = await readFile(`${dist}${file.replaceAll('..', '')}`);
      res.writeHead(200, { 'content-type': types[extname(file)] ?? 'application/octet-stream' });
      res.end(body);
    } catch {
      res.writeHead(404).end();
    }
  });
  await new Promise((done) => server.listen(0, '127.0.0.1', done));
  origin = `http://127.0.0.1:${server.address().port}`;
  browser = await chromium.launch();
});

after(async () => {
  await browser?.close();
  await new Promise((done) => (server ? server.close(done) : done()));
});

/**
 * Runs in the page. Freezes every animation at `time` seconds, then returns
 * the boxes (CSS px) of the visible cards, the content column and what a card
 * must not touch.
 */
function measure(time) {
  if (time !== null) {
    for (const animation of document.getAnimations()) {
      animation.pause();
      animation.currentTime = time * 1000;
    }
  }
  const box = (el) => {
    const { left, top, right, bottom } = el.getBoundingClientRect();
    return { left, top, right, bottom };
  };
  const q = (selector) => document.querySelector(selector);
  const cards = [...document.querySelectorAll('.hero__quote')]
    .filter((card) => getComputedStyle(card).visibility !== 'hidden' && card.offsetParent !== null)
    .map((card) => ({ name: card.textContent.trim().slice(0, 24), ...box(card) }));
  const pause = q('.hero__pause');
  return {
    cards,
    column: box(q('.hero .wrap')),
    avoid: {
      title: box(q('.hero__title')),
      lead: box(q('.hero__lead')),
      ...Object.fromEntries([...document.querySelectorAll('.hero .actions .btn')].map((b, i) => [`button ${i + 1}`, box(b)])),
      ...(pause && getComputedStyle(pause).display !== 'none' ? { pause: box(pause) } : {}),
    },
    // Nothing the orbit draws may take a click meant for a button.
    blockedButtons: [...document.querySelectorAll('.hero .actions .btn')]
      .filter((b) => {
        const { left, top, width, height } = b.getBoundingClientRect();
        return document.elementFromPoint(left + width / 2, top + height / 2) !== b;
      })
      .map((b) => b.textContent.trim()),
    scrollWidth: document.documentElement.scrollWidth,
    innerWidth: window.innerWidth,
  };
}

const hits = (a, b) => a.left < b.right && b.left < a.right && a.top < b.bottom && b.top < a.bottom;

function violations({ cards, column, avoid, blockedButtons, scrollWidth, innerWidth }, label) {
  const found = [];
  // Half a pixel absorbs sub-pixel layout, nothing more.
  const eps = 0.5;
  for (const card of cards) {
    if (card.left < column.left - eps || card.right > column.right + eps) {
      found.push(`${label}: "${card.name}" leaves the column (${card.left.toFixed(1)} to ${card.right.toFixed(1)}, column ${column.left} to ${column.right})`);
    }
    for (const [what, target] of Object.entries(avoid)) {
      if (hits(card, target)) found.push(`${label}: "${card.name}" covers the ${what}`);
    }
  }
  for (const name of blockedButtons) found.push(`${label}: the "${name}" button does not receive a click at its centre`);
  if (scrollWidth > innerWidth) found.push(`${label}: horizontal scroll (${scrollWidth} > ${innerWidth})`);
  return found;
}

async function open(width, reducedMotion) {
  const context = await browser.newContext({ viewport: { width, height: 900 }, reducedMotion, colorScheme: 'light' });
  const page = await context.newPage();
  await page.goto(origin, { waitUntil: 'load' });
  await page.evaluate(() => document.fonts.ready);
  return { context, page };
}

describe('hero orbit', () => {
  for (const width of widths) {
    test(`${width} px: cards stay in the column and clear of the text, buttons and pause button`, async () => {
      const { context, page } = await open(width, 'no-preference');
      try {
        await page.waitForSelector('.hero__pause:not([hidden])');
        assert.ok(await page.evaluate(() => document.getAnimations().length > 0), 'the orbit is animated');

        const found = [];
        for (const time of times) {
          const state = await page.evaluate(measure, time);
          assert.ok(state.cards.length >= 4, `at ${time} s only ${state.cards.length} cards are visible`);
          found.push(...violations(state, `t=${time}s`));
        }
        assert.deepEqual(found, []);
      } finally {
        await context.close();
      }
    });

    test(`${width} px, reduced motion: the still cards obey the same rules`, async () => {
      const { context, page } = await open(width, 'reduce');
      try {
        assert.equal(await page.evaluate(() => document.getAnimations().length), 0);
        assert.deepEqual(violations(await page.evaluate(measure, null), 'still'), []);
      } finally {
        await context.close();
      }
    });
  }
});
