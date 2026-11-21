// Local preview server: `node serve.mjs [port]`. Dev only.
// Serves this folder, and maps the app path so the concept links work:
// /app/ shows the open-a-course screen (app-home-empty.html, link field
// focused); the signed-in home is app-home.html. The real site serves the
// Flutter build under /app/.
import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { dirname, join, extname, normalize } from 'node:path';

const root = dirname(fileURLToPath(import.meta.url));
const types = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.svg': 'image/svg+xml',
  '.woff2': 'font/woff2',
  '.webp': 'image/webp',
};

// The CSP the Worker will send (security review R18), so the preview fails the
// same way production would.
// Only the catalog filter runs a script; every other page gets script-src 'none'.
const csp = (script) =>
  `default-src 'none'; style-src 'self'; font-src 'self'; img-src 'self'; script-src ${script}; ` +
  "connect-src 'none'; base-uri 'none'; form-action 'self'; object-src 'none'; frame-ancestors 'none'";

createServer(async (req, res) => {
  let path = decodeURIComponent(new URL(req.url, 'http://x').pathname);
  if (path === '/' || path === '') path = '/index.html';
  if (path === '/app' || path.startsWith('/app/')) path = '/app-home-empty.html';
  const file = join(root, normalize(path));
  if (!file.startsWith(root)) {
    res.writeHead(403).end();
    return;
  }
  try {
    const body = await readFile(file);
    res.writeHead(200, {
      'content-type': types[extname(file)] ?? 'application/octet-stream',
      'content-security-policy': csp(path === '/catalog.html' ? "'self'" : "'none'"),
      'x-content-type-options': 'nosniff',
      'referrer-policy': 'strict-origin-when-cross-origin',
      'permissions-policy': 'camera=(), microphone=(), geolocation=(), interest-cohort=()',
    });
    res.end(body);
  } catch {
    res.writeHead(404, { 'content-type': 'text/plain' }).end('Not found');
  }
}).listen(Number(process.argv[2] ?? 8123), '127.0.0.1');
