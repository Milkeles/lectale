// Writes qr/android.svg: the static QR code for the download section (R22).
//
// Run: QR_MODULE=/path/to/node_modules/qr/index.js node make-qr.mjs
// The `qr` package (MIT OR Apache-2.0, zero dependencies) lives in a scratch
// folder, not in this repository.
import { writeFileSync, mkdirSync } from 'node:fs';
import { pathToFileURL, fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));
const { default: encodeQR } = await import(pathToFileURL(process.env.QR_MODULE).href);

// R22: the code encodes the canonical HTTPS URL, and the page prints it. The
// route does not exist until the site is built; the Worker will answer it with
// a redirect to releases/latest/download/lectale-android.apk, so the printed
// code never has to change when the release asset does.
export const CANONICAL_URL = 'https://lectale.fervorgames.workers.dev/download/android';

// Dark modules on a light tile in both colour schemes: inverted codes fail on
// many scanners (NN/g QR guideline 7). A 4-module border is the quiet zone.
const PAPER = '#F4F1ED';
const GRAPHITE = '#242725';

const raw = encodeQR(CANONICAL_URL, 'svg', { ecc: 'medium', border: 4 });
const svg = raw
  .replace('<svg ', '<svg width="164" height="164" shape-rendering="crispEdges" ')
  .replace('<path ', `<rect width="100%" height="100%" fill="${PAPER}"/><path fill="${GRAPHITE}" `);

mkdirSync(join(here, 'qr'), { recursive: true });
writeFileSync(join(here, 'qr', 'android.svg'), svg + '\n');
console.log('qr/android.svg', svg.length, 'bytes');
