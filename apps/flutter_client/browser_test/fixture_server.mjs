// A small server for browser checks: the Flutter web build under /app/ and a
// fixture course under /api, the way the Worker serves them.
//
// Used by security.test.mjs, and by hand for screenshots:
//   node browser_test/fixture_server.mjs build/web 8123
import { createServer } from 'node:http';
import { existsSync, readFileSync, statSync } from 'node:fs';
import { dirname, extname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));

export const REPO_ID = 42;
export const SHA = 'a'.repeat(40);
export const BASE = `/api/preview/${REPO_ID}/${SHA}`;

/** The README of the security fixture: hostile and valid images side by side. */
export const securityReadme = `# Security fixture

Remote tracker: ![tracker](https://tracker.example/pixel.png)

Encoded climb: ![climb](/%2e%2e/secret.png) and ![deeper](%2e%2e/%2e%2e/secret.png)

Malformed: ![bad](%FF.png)

Valid: ![A histogram of exam scores](figures/histogram.png)

[A tracked link](http://tracker.example/click) and [a script](javascript:alert(1))
`;

const note = `# Notes

A lesson with its own relative image: ![Scores](../../figures/histogram.png)
`;

function resource(id, kind, title, lesson, path, extension) {
  return {
    id, kind, title,
    href: `${BASE}/content/${lesson}/${id}`,
    path, fileExtension: extension,
  };
}

export const preview = {
  repoId: REPO_ID,
  sha: SHA,
  readmePresent: true,
  outline: {
    course: {
      id: 'security-fixture',
      title: 'Security fixture',
      summary: 'A course whose Markdown tries to reach other hosts.',
      language: 'en',
      version: '1.0.0',
    },
    nodes: [
      {
        id: 'one', kind: 'lesson', title: 'One', children: [],
        resources: [resource('notes', 'markdown', 'Notes', 'one', 'lessons/one/notes.md', 'md')],
      },
    ],
    assignments: [],
  },
};

const types = {
  '.html': 'text/html', '.js': 'text/javascript', '.json': 'application/json',
  '.png': 'image/png', '.wasm': 'application/wasm', '.otf': 'font/otf',
  '.ttf': 'font/ttf', '.map': 'application/json',
};

/**
 * Starts the server on [port] (0 for any) and resolves to
 * `{ server, origin, requests }`; `requests` lists every request path seen.
 */
export function startFixture({ webDir, port = 0, readme = securityReadme }) {
  const requests = [];
  const histogram = readFileSync(join(here, 'fixture', 'histogram.png'));
  const files = {
    [`${BASE}/readme`]: ['text/markdown', readme],
    [`${BASE}/content/one/notes`]: ['text/markdown', note],
    [`${BASE}/files/figures/histogram.png`]: ['image/png', histogram],
  };
  const server = createServer((req, res) => {
    const url = new URL(req.url, 'http://fixture');
    requests.push(`${req.method} ${url.pathname}${url.search}`);
    if (url.pathname === BASE) {
      res.writeHead(200, { 'content-type': 'application/json' });
      return res.end(JSON.stringify(preview));
    }
    if (files[url.pathname]) {
      const [type, body] = files[url.pathname];
      res.writeHead(200, { 'content-type': type });
      return res.end(body);
    }
    if (url.pathname.startsWith('/api/')) {
      res.writeHead(404, { 'content-type': 'application/json' });
      return res.end(JSON.stringify({
        code: 'course_not_found', message: 'x', requestId: 'fixture', retryable: false,
      }));
    }
    let path = url.pathname.replace(/^\/app\//, '');
    if (url.pathname === '/app' || path === '') path = 'index.html';
    const file = join(webDir, path);
    if (existsSync(file) && statSync(file).isFile()) {
      res.writeHead(200, { 'content-type': types[extname(file)] ?? 'application/octet-stream' });
      return res.end(readFileSync(file));
    }
    res.writeHead(404);
    res.end('not found');
  });
  return new Promise((resolve) => {
    server.listen(port, '127.0.0.1', () => {
      resolve({ server, origin: `http://127.0.0.1:${server.address().port}`, requests });
    });
  });
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const [webDir, port] = process.argv.slice(2);
  const { origin } = await startFixture({ webDir, port: Number(port) });
  console.log(`listening on ${origin}`);
}
