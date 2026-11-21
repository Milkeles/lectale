// Dev check, not part of the site: screenshots and axe-core for every page.
//
//   node serve.mjs 8123 &
//   PW=/path/to/node_modules/playwright-core/index.mjs \
//   AXE=/path/to/node_modules/axe-core/axe.min.js \
//   OUT=/path/to/png-folder node shoot.mjs [page-name ...]
//
// PNGs are written to OUT; convert them to WebP (screens/) afterwards.
// Reports: axe violations, requests to any host other than the preview
// server, CSP violations and cookies.
import { readFileSync, mkdirSync } from 'node:fs';
import { pathToFileURL } from 'node:url';

const { chromium } = await import(pathToFileURL(process.env.PW).href);
const axeSource = readFileSync(process.env.AXE, 'utf8');
const out = process.env.OUT;
const base = process.env.BASE ?? 'http://127.0.0.1:8123';
mkdirSync(out, { recursive: true });

const pages = {
  index: 'index.html',
  'index-hook-d': 'index-hook-d.html',
  catalog: 'catalog.html',
  'catalog-no-results': 'catalog.html?q=quantum',
  login: 'login.html',
  'login-error': 'login-error.html',
  'login-unconfirmed': 'login-unconfirmed.html',
  'login-expired': 'login-expired.html',
  'create-account': 'create-account.html',
  'create-account-sent': 'create-account-sent.html',
  'app-home': 'app-home.html',
  'app-home-menu': 'app-home-menu.html',
  'app-home-empty': 'app-home-empty.html',
};
const only = process.argv.slice(2);
const names = only.length ? only : Object.keys(pages);
const widths = [
  [1440, 900],
  [390, 844],
];
const tags = ['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa', 'wcag22aa', 'best-practice'];

const browser = await chromium.launch({ executablePath: '/usr/bin/google-chrome' });
let violationsTotal = 0;
const foreign = new Set();
const csp = [];

for (const name of names) {
  for (const [w, h] of widths) {
    for (const scheme of ['light', 'dark']) {
      const ctx = await browser.newContext({
        viewport: { width: w, height: h },
        colorScheme: scheme,
        deviceScaleFactor: 1,
        // fullPage capture restarts CSS animations; the reduced-motion path shows the ribbon at rest.
        reducedMotion: 'reduce',
      });
      const page = await ctx.newPage();
      page.on('request', (r) => {
        if (!r.url().startsWith(base)) foreign.add(r.url());
      });
      page.on('console', (m) => {
        if (/Content Security Policy|Refused to/i.test(m.text())) csp.push(`${name}: ${m.text()}`);
      });
      await page.goto(`${base}/${pages[name]}`, { waitUntil: 'networkidle' });
      await page.evaluate(() => document.fonts.ready);
      // Lazy images only load near the viewport: scroll through, then back.
      await page.evaluate(async () => {
        for (let y = 0; y < document.body.scrollHeight; y += 600) {
          window.scrollTo(0, y);
          await new Promise((r) => setTimeout(r, 40));
        }
        window.scrollTo(0, 0);
      });
      await page.waitForTimeout(name.startsWith('index') ? 1500 : 300);
      await page.screenshot({ path: `${out}/${name}-${w}-${scheme}.png`, fullPage: true });

      await page.evaluate(axeSource);
      const res = await page.evaluate((t) => axe.run(document, { runOnly: { type: 'tag', values: t } }), tags);
      for (const v of res.violations) {
        violationsTotal += 1;
        console.log(`AXE ${name} ${w} ${scheme}: ${v.id} (${v.impact}) ${v.help}`);
        for (const n of v.nodes.slice(0, 3)) console.log(`   ${n.target.join(' ')}  ${n.failureSummary?.split('\n')[1] ?? ''}`);
      }
      const cookies = await ctx.cookies();
      if (cookies.length || (await page.evaluate(() => document.cookie))) console.log(`COOKIE ${name}`);
      await ctx.close();
    }
  }
}
await browser.close();
console.log(`axe violations: ${violationsTotal}`);
console.log(`requests to other hosts: ${foreign.size}`, [...foreign]);
console.log(`CSP messages: ${csp.length}`, csp.slice(0, 5));
