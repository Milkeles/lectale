import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { test } from 'node:test';
import decodeQR from 'qr/decode.js';
import { ANDROID_QR_URL } from '../build.mjs';

const dist = new URL('../dist/', import.meta.url);
const read = (name) => readFile(new URL(name, dist), 'utf8');
const html = await read('index.html');
const origin = new URL(ANDROID_QR_URL).origin;
const github = 'https://github.com/Milkeles/lectale/';
const releaseLink = /^https:\/\/github\.com\/Milkeles\/lectale\/releases\//;
const tags = [...html.matchAll(/<([a-z][\w-]*)\b[^>]*>/gi)];
const csp = "default-src 'none'; style-src 'self'; font-src 'self'; img-src 'self'; script-src 'self'; connect-src 'none'; base-uri 'none'; form-action 'self'; object-src 'none'; frame-ancestors 'none'; upgrade-insecure-requests";

test('A11Y-001: native links provide the keyboard path to the primary action', () => {
  const links = [...html.matchAll(/<a\b[^>]* href="([^"]+)"/g)].map(([, href]) => href);
  assert.deepEqual(links.slice(0, 9), [
    '#main', '/', '#catalog', '#download', '#instructors', '/app/', '/app/',
    '#instructors', '#catalog',
  ]);
  assert.match(html, /<main id="main" tabindex="-1">/);
  assert.match(html, /<a class="btn btn--primary btn--lg" href="#instructors">Make a course<\/a>/);
  assert.match(html, /<section\b[^>]* id="instructors"/);
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
