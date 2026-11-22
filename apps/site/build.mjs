import { cp, mkdir, readFile, rm, writeFile } from 'node:fs/promises';
import { pathToFileURL } from 'node:url';
import encodeQR from 'qr';

export const ANDROID_QR_URL = 'https://lectale.fervorgames.workers.dev/download/android';
const RELEASES = 'https://github.com/Milkeles/lectale/releases';
const RELEASE_ASSETS = `${RELEASES}/latest/download`;
const src = new URL('./src/', import.meta.url);
const dist = new URL('./dist/', import.meta.url);
const flutter = new URL('../flutter_client/build/web/', import.meta.url);
const assets = new URL('../edge_api/build/assets/', import.meta.url);

async function buildSite() {
  const [page, hero] = await Promise.all([
    readFile(new URL('index.html', src), 'utf8'),
    readFile(new URL('partials/hero.html', src), 'utf8'),
  ]);
  const landing = page
    .replace('<!-- hero -->', () => hero.trimEnd())
    .replaceAll('{{release-assets}}', RELEASE_ASSETS)
    .replaceAll('{{releases}}', RELEASES)
    .replaceAll('{{android-qr-url}}', ANDROID_QR_URL);

  // R22 requires a local, printable QR code. The light tile and four-module
  // border keep it readable in either colour scheme.
  const svg = encodeQR(ANDROID_QR_URL, 'svg', { ecc: 'medium', border: 4 })
    .replace('<svg ', '<svg width="164" height="164" shape-rendering="crispEdges" ')
    .replace('<path ', '<rect width="100%" height="100%" fill="#F4F1ED"/><path fill="#242725" ');
  const redirect = `${new URL(ANDROID_QR_URL).pathname} ${RELEASE_ASSETS}/lectale-android.apk 302\n`;

  await rm(dist, { recursive: true, force: true });
  await mkdir(new URL('qr/', dist), { recursive: true });
  const files = ['404.html', 'site.css', 'hero-quotes.js', 'logo.svg', 'fonts', 'covers', 'art', '_headers'];
  await Promise.all([
    ...files.map((name) => cp(new URL(name, src), new URL(name, dist), { recursive: true })),
    writeFile(new URL('index.html', dist), landing),
    writeFile(new URL('qr/android.svg', dist), `${svg}\n`),
    writeFile(new URL('_redirects', dist), redirect),
  ]);
}

async function assemble() {
  const index = await readFile(new URL('index.html', flutter), 'utf8');
  if (!index.includes('<base href="/app/">')) {
    throw new Error('Build Flutter with flutter build web --release --base-href /app/.');
  }
  await rm(assets, { recursive: true, force: true });
  await cp(dist, assets, { recursive: true });
  await cp(flutter, new URL('app/', assets), { recursive: true });
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  await buildSite();
  if (process.argv.includes('--with-app')) await assemble();
}
