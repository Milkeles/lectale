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

// Placeholder release URL (brief). R21 and R22: this project's Releases only.
export const RELEASES_URL = 'https://github.com/Milkeles/lectale/releases/latest';

// Dark modules on a light tile in both colour schemes: inverted codes fail on
// many scanners (NN/g QR guideline 7). A 4-module border is the quiet zone.
const PAPER = '#F4F1ED';
const GRAPHITE = '#242725';

const raw = encodeQR(RELEASES_URL, 'svg', { ecc: 'medium', border: 4 });
const svg = raw
  .replace('<svg ', '<svg width="164" height="164" shape-rendering="crispEdges" ')
  .replace('<path ', `<rect width="100%" height="100%" fill="${PAPER}"/><path fill="${GRAPHITE}" `);

mkdirSync(join(here, 'qr'), { recursive: true });
writeFileSync(join(here, 'qr', 'android.svg'), svg + '\n');
console.log('qr/android.svg', svg.length, 'bytes');
