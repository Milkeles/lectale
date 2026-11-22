import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { test } from 'node:test';
import { runInNewContext } from 'node:vm';
import decodeQR from 'qr/decode.js';
import { ANDROID_QR_URL } from '../build.mjs';

const dist = new URL('../dist/', import.meta.url);
const read = (name) => readFile(new URL(name, dist), 'utf8');
const html = await read('index.html');
const origin = new URL(ANDROID_QR_URL).origin;
const github = 'https://github.com/Milkeles/lectale/';
const releaseLink = /^https:\/\/github\.com\/Milkeles\/lectale\/releases\//;
const tags = [...html.matchAll(/<([a-z][\w-]*)\b[^>]*>/gi)];
const hero = html.match(/<section class="hero"[^>]*>([\s\S]*?)<\/section>/)?.[1] ?? '';
const csp = "default-src 'none'; style-src 'self'; font-src 'self'; img-src 'self'; script-src 'self'; connect-src 'none'; base-uri 'none'; form-action 'self'; object-src 'none'; frame-ancestors 'none'; upgrade-insecure-requests";

test('A11Y-001: native links provide the keyboard path to the primary action', () => {
  const links = [...html.matchAll(/<a\b[^>]* href="([^"]+)"/g)].map(([, href]) => href);
  assert.deepEqual(links.slice(0, 9), [
    '#main', '/', '#catalog', '#download', '#instructors', '/app/', '/app/',
    '/app/#/open', '#instructors',
  ]);
  assert.match(html, /<main id="main" tabindex="-1">/);
  assert.match(hero, /<a class="btn btn--primary btn--lg" href="\/app\/#\/open">Open a course<\/a>/);
  assert.match(hero, /<a class="btn btn--outline btn--lg" href="#instructors">Make a course<\/a>/);
  assert.match(html, /<section\b[^>]* id="instructors"/);
});

test('the hero has one heading with the approved copy', () => {
  const headings = [...hero.matchAll(/<h1\b[^>]*>([^<]*)<\/h1>/g)].map(([, text]) => text);
  assert.deepEqual(headings, ['Your course, online in minutes.']);
});

test('A11Y-001: the pause button toggles the orbit from the local script', async () => {
  const button = hero.match(/<button\b[^>]* class="btn hero__pause"[^>]*>([\s\S]*?)<\/button>/);
  assert.match(button?.[0] ?? '', /type="button" aria-label="Pause quotes" aria-pressed="false" hidden/);
  assert.match(button?.[1] ?? '', /^\s*<svg\b[^>]* aria-hidden="true"[^>]*>[\s\S]*<\/svg>\s*$/);
  assert.match(html, /<script src="hero-quotes\.js" defer><\/script>/);

  const attributes = new Map([['aria-pressed', 'false']]);
  const listeners = new Map();
  const pause = {
    hidden: true,
    getAttribute: attributes.get.bind(attributes),
    setAttribute: attributes.set.bind(attributes),
    addEventListener: listeners.set.bind(listeners),
  };
  runInNewContext(await read('hero-quotes.js'), {
    document: {
      querySelector(selector) {
        assert.equal(selector, '.hero__pause');
        return pause;
      },
    },
  });
  assert.equal(pause.hidden, false);
  listeners.get('click')();
  assert.equal(attributes.get('aria-pressed'), 'true');
  listeners.get('click')();
  assert.equal(attributes.get('aria-pressed'), 'false');

  const css = await read('site.css');
  assert.match(css, /--orbit-lap: 72s;/);
  assert.match(css, /@media \(prefers-reduced-motion: no-preference\)\s*\{\s*\.hero__pause:not\(\[hidden\]\)\s*\+\s*\.hero__orbit \.hero__quote\s*\{\s*animation: quote-orbit var\(--orbit-lap\) linear infinite;/);
  assert.match(css, /\.hero__pause\[aria-pressed="true"\]\s*\+\s*\.hero__orbit \.hero__quote\s*\{\s*animation-play-state: paused;/);
  assert.match(css, /@media \(prefers-reduced-motion: reduce\)\s*\{\s*\.hero \.hero__pause\s*\{\s*display: none;/);
});

test('the static and aria-hidden copies contain the same quotations', () => {
  const visible = hero.match(/<ul class="hero__quote-track" aria-hidden="true">([\s\S]*?)<\/ul>/)?.[1] ?? '';
  const accessible = hero.match(/<ul class="vh" aria-label="Quotations on learning and reading">([\s\S]*?)<\/ul>/)?.[1] ?? '';
  const quotations = (list) => [...list.matchAll(/<blockquote>([^<]+)<\/blockquote>/g)].map(([, text]) => text);
  assert.equal(quotations(accessible).length, 5);
  assert.deepEqual(quotations(visible), quotations(accessible));
  assert.match(visible, /<blockquote>Come, Boy, learn to be wise\.<\/blockquote><span class="hero__credit"><span>Johann Amos Comenius,<\/span> <span>trans\. Charles Hoole<\/span><\/span>/);
  assert.match(accessible, /translated by Charles Hoole/);
  assert.doesNotMatch(accessible, /trans\./);
  assert.doesNotMatch(hero, /Samuel Johnson/);
  assert.equal([...accessible.matchAll(/<cite>[^<]+<\/cite>/g)].length, 5);
});

test('the decorative book has intrinsic dimensions and both local formats', async () => {
  assert.match(hero, /<picture class="hero__book">\s*<source type="image\/avif"/);
  assert.match(hero, /<img\b[^>]*src="art\/open-book\.webp"[^>]*width="256" height="136" alt=""/);
  for (const suffix of ['.avif', '.webp']) {
    for (const name of ['open-book', 'open-book-small']) {
      const file = new URL(`art/${name}${suffix}`, dist);
      assert.ok((await readFile(file)).length > 0);
    }
    for (const name of ['book', 'book-small']) {
      await assert.rejects(readFile(new URL(`art/${name}${suffix}`, dist)), { code: 'ENOENT' });
    }
  }
});

test('R17: assets are same-origin and outbound links stay within GitHub or mailto', () => {
  for (const [tag, element] of tags) {
    const attributes = tag.matchAll(/\s(href|src)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+))/gi);
    for (const [, attribute, doubleQuoted, singleQuoted, unquoted] of attributes) {
      const value = doubleQuoted ?? singleQuoted ?? unquoted;
      const url = new URL(value, origin);
      const allowedLink = element.toLowerCase() === 'a' && attribute.toLowerCase() === 'href'
        && (url.href.startsWith(github) || url.protocol === 'mailto:');
      assert.ok(url.origin === origin || allowedLink, `Unexpected URL in ${tag}`);
    }
    const srcset = tag.match(/\ssrcset="([^"]+)"/)?.[1];
    for (const candidate of srcset?.split(',') ?? []) {
      const [value] = candidate.trim().split(/\s+/);
      assert.equal(new URL(value, origin).origin, origin, `Unexpected URL in ${tag}`);
    }
  }
});

test('R21: every native download and the Android redirect use Lectale releases', async () => {
  const downloads = [...html.matchAll(/<li class="plat">([\s\S]*?)<\/li>/g)];
  assert.equal(downloads.length, 4);
  for (const [, row] of downloads) {
    assert.match(row.match(/<a\b[^>]* href="([^"]+)"/)?.[1] ?? '', releaseLink);
  }
  const [path, target, status] = (await read('_redirects')).trim().split(/\s+/);
  assert.equal(path, new URL(ANDROID_QR_URL).pathname);
  assert.equal(target, `${github}releases/latest/download/lectale-android.apk`);
  assert.equal(status, '302');
});

test('R22: the SVG decodes to the printed canonical Android URL', async () => {
  assert.match(html, /<img\b[^>]* src="qr\/android\.svg"/);
  assert.equal(html.match(/<p class="qr__url t-mono">([^<]+)<\/p>/)?.[1], ANDROID_QR_URL);

  // qr 0.7.2 emits one closed unit square per dark module. Rasterize those
  // squares at 4 pixels per module so the package's reader can scan the SVG.
  const svg = await read('qr/android.svg');
  const modules = Number(svg.match(/viewBox="0 0 (\d+) \1"/)?.[1]);
  const path = svg.match(/<path\b[^>]* d="([^"]+)"/)?.[1];
  assert.ok(modules && path);
  const width = modules * 4;
  const data = new Uint8Array(width * width * 4).fill(255);
  const squares = /([Mm])(-?\d+) (-?\d+)h1v1(?:h-1|H\d+)Z/g;
  assert.equal(path.replace(squares, ''), '');
  let x = 0;
  let y = 0;
  for (const [, move, dx, dy] of path.matchAll(squares)) {
    x = (move === 'M' ? 0 : x) + Number(dx);
    y = (move === 'M' ? 0 : y) + Number(dy);
    for (let row = y * 4; row < (y + 1) * 4; row++) {
      const start = (row * width + x * 4) * 4;
      data.fill(0, start, start + 16);
    }
  }
  assert.equal(decodeQR({ width, height: width, data }), ANDROID_QR_URL);
});

test('R18–R20: the landing CSP, Flutter exception and cover sandbox are declared', async () => {
  const headers = await read('_headers');
  assert.ok(headers.includes(`\n/*\n  Content-Security-Policy: ${csp}\n`));
  assert.match(headers, /\n  X-Content-Type-Options: nosniff\n/);
  assert.match(headers, /\n  Referrer-Policy: strict-origin-when-cross-origin\n/);
  assert.match(headers, /\n  Permissions-Policy: camera=\(\), microphone=\(\), geolocation=\(\)\n/);
  assert.match(headers, /\n\/app\/\*\n  ! Content-Security-Policy\n/);
  assert.match(headers, /\n\/covers\/\*\n  ! Content-Security-Policy\n  Content-Security-Policy: sandbox\n/);
});

test('R18: scripts have no inline content', () => {
  for (const [, content] of html.matchAll(/<script\b[^>]*>([\s\S]*?)<\/script\s*>/gi)) {
    assert.equal(content.trim(), '');
  }
});
