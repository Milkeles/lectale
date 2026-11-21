// Local preview server: `node serve.mjs [port]`. Dev only.
// Serves this folder, and maps the app path so the concept links work:
// /app/ shows the signed-in home mock. The real site serves the Flutter build there.
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
const csp =
  "default-src 'none'; style-src 'self'; font-src 'self'; img-src 'self'; script-src 'self'; " +
  "connect-src 'none'; base-uri 'none'; form-action 'self'; object-src 'none'; frame-ancestors 'none'";

createServer(async (req, res) => {
  let path = decodeURIComponent(new URL(req.url, 'http://x').pathname);
  if (path === '/' || path === '') path = '/index.html';
  if (path === '/app' || path.startsWith('/app/')) path = '/app-home.html';
  const file = join(root, normalize(path));
  if (!file.startsWith(root)) {
    res.writeHead(403).end();
    return;
  }
  try {
    const body = await readFile(file);
    res.writeHead(200, {
      'content-type': types[extname(file)] ?? 'application/octet-stream',
      'content-security-policy': csp,
      'x-content-type-options': 'nosniff',
    });
    res.end(body);
  } catch {
    res.writeHead(404, { 'content-type': 'text/plain' }).end('Not found');
  }
}).listen(Number(process.argv[2] ?? 8123), '127.0.0.1');
