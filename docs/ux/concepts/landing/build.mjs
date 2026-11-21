// Generates the concept pages as plain static HTML: `node build.mjs`.
//
// The output has no inline script or style (CSP, security review R18), no
// third-party request and no cookie.
import { writeFileSync, copyFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));
const out = (name, html) => writeFileSync(join(here, name), html);

// ---------- Constants ----------

const OWNER_REPO = 'https://github.com/Milkeles/lectale';
const RELEASES = `${OWNER_REPO}/releases/latest`;
// GitHub's stable "latest" form: the asset names are fixed by the release
// workflow, so these links never change between releases (R21).
const DOWNLOAD = `${RELEASES}/download`;
const CANONICAL_ANDROID = 'https://lectale.fervorgames.workers.dev/download/android'; // R22; see make-qr.mjs
const APP = '/app/';
const APP_OPEN = '/app/#/open'; // the app's open-a-course screen, link field focused
const APP_LOGIN = '/app/#/login';
const APP_CREATE = '/app/#/create-account';

const HERO = {
  lines: ['Open the course.', 'Close the other tabs.'],
  lead: 'Lectale opens a course from its GitHub repository and shows its lessons, PDFs, notebooks, video and audio in one place.',
  free: 'Free to read, no account needed.',
};

// Example courses. Every one is labelled as an example (copy 4.4).
const COURSES = [
  {
    slug: 'introduction-to-statistics',
    title: 'Introduction to statistics',
    summary: 'Describe data, read charts and test simple ideas.',
    lang: 'English', code: 'en', subject: 'Statistics',
  },
  {
    slug: 'reading-medieval-manuscripts',
    title: 'Reading medieval manuscripts',
    summary: 'Learn to date and transcribe handwriting from scanned pages.',
    lang: 'English', code: 'en', subject: 'History',
  },
  {
    slug: 'python-for-lab-data',
    title: 'Python for lab data',
    summary: 'Clean, plot and share measurements in notebooks.',
    lang: 'English', code: 'en', subject: 'Computing',
  },
  {
    slug: 'osnovi-na-logikata',
    title: 'Основи на логиката',
    summary: 'Научете се да разпознавате валидни и невалидни аргументи.',
    lang: 'Bulgarian', code: 'bg', subject: 'Philosophy',
  },
  {
    slug: 'cell-biology-lab-guide',
    title: 'Cell biology lab guide',
    summary: 'Prepare slides, use a microscope and record what you see.',
    lang: 'English', code: 'en', subject: 'Biology',
  },
  {
    slug: null, // no `course.cover` in its course.yaml: the title is drawn as text
    title: 'Field methods in ecology',
    summary: 'Plan a survey, collect samples and write up the results.',
    lang: 'English', code: 'en', subject: 'Biology',
  },
];

// ---------- Fragments ----------

const MARK = '<svg viewBox="0 0 64 64" aria-hidden="true" focusable="false"><path d="M8 4H20V36L28 28L36 36V4C47 4 56 13 56 24V60H8Z"/></svg>';

const ICONS = {
  alert: '<svg viewBox="0 0 24 24" aria-hidden="true" focusable="false"><circle cx="12" cy="12" r="10"/><path d="M12 8v4"/><path d="M12 16h.01"/></svg>',
  info: '<svg viewBox="0 0 24 24" aria-hidden="true" focusable="false"><circle cx="12" cy="12" r="10"/><path d="M12 16v-4"/><path d="M12 8h.01"/></svg>',
  down: '<svg viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path d="m6 9 6 6 6-6"/></svg>',
};

function head({ title, description, noindex = false, script = false }) {
  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${title}</title>
<meta name="description" content="${description}">
<meta name="color-scheme" content="light dark">
<meta name="theme-color" content="#f4f1ed" media="(prefers-color-scheme: light)">
<meta name="theme-color" content="#191b1a" media="(prefers-color-scheme: dark)">
<meta name="referrer" content="strict-origin-when-cross-origin">${noindex ? '\n<meta name="robots" content="noindex">' : ''}
<link rel="icon" href="logo.svg" type="image/svg+xml">
<link rel="preload" href="fonts/SourceSerif4Variable-Roman.ttf.woff2" as="font" type="font/woff2" crossorigin>
<link rel="stylesheet" href="site.css">${script ? '\n<script src="catalog.js" defer></script>' : ''}
</head>
<body>
<a class="skip" href="#main">Skip to main content</a>
`;
}

const brand = (href = 'index.html') =>
  `<a class="brand" href="${href}" aria-label="Lectale, home">${MARK}<span aria-hidden="true">Lectale</span></a>`;

function siteHeader(current = '') {
  const cur = (k) => (current === k ? ' aria-current="page"' : '');
  return `<header class="site">
  <div class="wrap site__row">
    ${brand()}
    <nav class="site__nav" aria-label="Main">
      <ul class="nav">
        <li><a href="catalog.html"${cur('catalog')}>Catalog</a></li>
        <li><a href="index.html#download">Download</a></li>
        <li><a href="index.html#instructors">For instructors</a></li>
      </ul>
    </nav>
    <div class="account">
      <a href="${APP_LOGIN}">Log in</a>
      <a class="btn btn--outline btn--sm" href="${APP_CREATE}">Create account</a>
    </div>
  </div>
</header>
`;
}

const footer = `<footer class="foot">
  <div class="wrap">
    <div class="grid foot__grid">
      <div class="foot__brand">
        ${brand('#top')}
        <p class="t-muted">Open and read courses from GitHub repositories.</p>
      </div>
      <nav class="foot__nav" aria-label="Footer">
        <ul>
          <li><a href="catalog.html">Catalog</a></li>
          <li><a href="index.html#download">Download</a></li>
          <li><a href="index.html#instructors">For instructors</a></li>
          <li><a href="/privacy/">Privacy notice</a></li>
          <li><a href="/terms/">Terms</a></li>
          <li><a href="/accessibility/">Accessibility</a></li>
        </ul>
      </nav>
    </div>
    <div class="foot__legal t-small">
      <p>Lectale is an independent project and is not affiliated with GitHub.</p>
      <p>© 2026 Lectale</p>
    </div>
  </div>
</footer>
</body>
</html>
`;

function card(c, { level = 3 } = {}) {
  const lang = c.code === 'en' ? '' : ` lang="${c.code}"`;
  const cover = c.slug
    ? `<img class="cover" src="covers/${c.slug}.svg" width="480" height="720" alt="" loading="lazy" decoding="async">`
    : `<div class="cover cover--none" aria-hidden="true"><span class="cover__title">${c.title}</span></div>`;
  return `<li class="card" data-course data-lang="${c.lang}" data-subject="${c.subject}" data-text="${(c.title + ' ' + c.summary).toLowerCase()}">
  ${cover}
  <div class="card__body">
    <h${level} class="card__title"><a href="${APP}" aria-label="${c.title}, example course"${lang}>${c.title}</a></h${level}>
    <p class="t-card"${lang}>${c.summary}</p>
    <p class="card__meta"><span>${c.lang}</span><span class="badge">Example course</span></p>
  </div>
</li>`;
}

// ---------- index.html ----------

function indexPage() {
  const platRow = ([name, fileName]) => `<li class="plat">
          <h3 class="plat__name">${name}</h3>
          <div class="plat__info"><p class="plat__file t-mono">${fileName}</p></div>
          <a class="btn btn--outline" href="${DOWNLOAD}/${fileName}">Download<span class="vh"> for ${name}</span></a>
        </li>`;
  const desktop = [
    ['Windows', 'lectale-windows-x64.zip'],
    ['macOS', 'lectale-macos.zip'],
    ['Linux', 'lectale-linux-x64.tar.gz'],
  ];

  return (
    head({
      title: 'Lectale: open and read courses from GitHub',
      description: HERO.lead,
    }) +
    siteHeader() +
    `<main id="main">

<section class="hero" id="top" aria-labelledby="hero-title">
  <div class="wrap">
    <h1 class="t-display hero__title" id="hero-title">${HERO.lines.map((l) => `<span>${l}</span>`).join(' ')}</h1>
    <p class="t-lead hero__lead">${HERO.lead}</p>
    <div class="actions">
      <a class="btn btn--primary btn--lg" href="${APP_OPEN}">Open a course</a>
      <a class="btn btn--outline btn--lg" href="catalog.html">Browse courses</a>
    </div>
    <p class="hero__free">${HERO.free}</p>

    <figure class="shot">
      <div class="shot__mat">
        <div class="app" aria-hidden="true">
          <div class="app__top">${MARK}<span>Introduction to statistics</span><span class="app__count"><span class="app__lesson">Lesson </span>3 of 7</span></div>
          <div class="app__body">
            <div class="app__pane">
              <div class="row">Overview</div>
              <div class="row row--mod">Describing data</div>
              <div class="row">What data looks like</div>
              <div class="row row--cur"><i class="ribbon"></i>Averages and spread</div>
              <div class="row">Reading a histogram</div>
              <div class="row row--mod">Testing ideas</div>
              <div class="row">Samples and populations</div>
              <div class="row">A first hypothesis test</div>
              <div class="row">Weekly problems</div>
            </div>
            <div class="app__main">
              <div class="read">
                <p class="read__mod">Describing data</p>
                <div class="read__head"><i class="ribbon"></i><p class="read__title">Averages and spread</p></div>
                <p class="read__text">The mean is the number most people reach for first. Add the values, divide by how many there are, and you have a single figure for where the middle sits.</p>
                <p class="read__text read__text--more">A single figure hides something, though. Two classes can both average 60 on a test. In one, almost everyone scored between 55 and 65. In the other, half the class scored near 30 and half near 90.</p>
              </div>
            </div>
          </div>
        </div>
      </div>
      <figcaption>A lesson from an example course, open in Lectale. The gold ribbon marks the lesson you are reading.</figcaption>
    </figure>
  </div>
</section>

<section class="section" id="read" aria-labelledby="read-h">
  <div class="wrap grid">
    <div class="section__head">
      <h2 class="t-h2" id="read-h">Everything in the course opens in the app</h2>
      <p class="t-read">Learners don’t need to download files or visit GitHub to read a lesson.</p>
    </div>
    <div class="section__body">
      <dl class="formats">
        <div><dt>Text</dt><dd>Lessons and course descriptions, as formatted pages.</dd></div>
        <div><dt>PDFs</dt><dd>Read slides and handouts without downloading them.</dd></div>
        <div><dt>Notebooks</dt><dd>A notebook is a document that mixes text, code and results. Lectale shows it. It does not run the code.</dd></div>
        <div><dt>Video</dt><dd>Watch lecture recordings. A video from another website asks your permission before it loads.</dd></div>
        <div><dt>Audio</dt><dd>Listen to recordings and read along.</dd></div>
        <div><dt>Code</dt><dd>Read code and data files as plain text.</dd></div>
      </dl>
      <p class="t-card formats__end t-muted">Any other file shows its name and size, with a safe download.</p>
    </div>
  </div>
</section>

<section class="section" id="how" aria-labelledby="how-h">
  <div class="wrap">
    <h2 class="t-h2" id="how-h">How to start</h2>
    <ol class="steps">
      <li><h3 class="t-h3">Find a course</h3><p class="t-card"><a href="${APP_OPEN}">Paste a course link</a>, or choose a course from the <a href="catalog.html">catalog</a>.</p></li>
      <li><h3 class="t-h3">Read it</h3><p class="t-card">Lectale shows the description, the outline and each lesson.</p></li>
      <li><h3 class="t-h3">Save a course or enrol</h3><p class="t-card">An account lets you enrol in a course or save it for later. Reading never needs one.</p></li>
    </ol>
  </div>
</section>

<section class="section" id="instructors" aria-labelledby="inst-h">
  <div class="wrap grid">
    <div class="section__head">
      <h2 class="t-h2" id="inst-h">Keep your course. Lectale presents it.</h2>
      <p class="t-read">Your course stays in a GitHub repository that you own. Lectale reads it and turns it into a course that learners open in the app.</p>
      <div class="keep">
        <div>
          <h3 class="t-h3">What you keep</h3>
          <ul>
            <li>Your files and your repository.</li>
            <li>Your choice of whether the course appears in the catalog. A new course starts unlisted.</li>
          </ul>
        </div>
        <div>
          <h3 class="t-h3">What you get</h3>
          <ul>
            <li>A course page built from your README and your outline.</li>
            <li>Enrolment: open, by approval or by invitation.</li>
            <li>Grades, kept in one place.</li>
          </ul>
        </div>
      </div>
    </div>
    <div class="section__body">
      <figure class="repo">
        <div class="repo__panel">
          <div class="repo__col">
            <h3 class="repo__h" id="repo-l">Your repository</h3>
            <ul class="tree" aria-labelledby="repo-l">
              <li><code>README.md</code></li>
              <li><code>course.yaml</code></li>
              <li><code>describing-data/</code></li>
              <li class="in"><code>what-data-looks-like.md</code></li>
              <li class="in"><code>averages-and-spread.md</code></li>
              <li class="in"><code>histograms.pdf</code></li>
            </ul>
          </div>
          <div class="repo__col">
            <h3 class="repo__h" id="repo-r">What learners see</h3>
            <ul class="outline" aria-labelledby="repo-r">
              <li>Overview</li>
              <li class="quiet">Sets the order and the titles</li>
              <li class="mod">Describing data</li>
              <li>What data looks like</li>
              <li>Averages and spread</li>
              <li>Reading a histogram</li>
            </ul>
          </div>
        </div>
        <figcaption class="cap">Lectale builds this outline from your course files.</figcaption>
      </figure>
      <div class="actions">
        <a class="btn btn--outline btn--lg" href="${APP_LOGIN}">Connect a repository</a>
        <a class="more" href="${APP_OPEN}">Open a course by link</a>
      </div>
    </div>
  </div>
</section>

<section class="section teaser" id="catalog" aria-labelledby="cat-h">
  <div class="wrap grid">
    <div class="teaser__head">
      <h2 class="t-h2" id="cat-h">Browse listed courses</h2>
      <p class="t-read">Instructors choose to list a course. Everything else can still be opened by its link.</p>
      <p><a class="more" href="catalog.html">Browse the catalog</a></p>
    </div>
    <div class="teaser__cards">
      <p class="cap">These are examples. They are not real courses.</p>
      <ul class="cards">
        ${COURSES.slice(0, 3).map((c) => card(c)).join('\n        ')}
      </ul>
    </div>
  </div>
</section>

<section class="section" id="download" aria-labelledby="dl-h">
  <div class="wrap">
    <div class="dl__head">
      <h2 class="t-h2" id="dl-h">Use Lectale on your device</h2>
      <p class="t-read">Use it in your browser, or install it.</p>
    </div>
    <div class="grid dl">
      <div class="dl__list">
        <ul class="plats">
          <li class="plat plat--web">
            <h3 class="plat__name">Web</h3>
            <div class="plat__info"><p class="plat__text t-card">Works on any device with a current browser. Nothing to install.</p></div>
            <a class="btn btn--primary" href="${APP_OPEN}">Open in browser</a>
          </li>
          <li class="plat">
            <h3 class="plat__name">Android app</h3>
            <div class="plat__info"><p class="plat__file t-mono">lectale-android.apk</p><p class="plat__more t-small">Your phone may ask you to allow installing from your browser.</p></div>
            <a class="btn btn--outline" href="${DOWNLOAD}/lectale-android.apk">Download<span class="vh"> the Android app</span></a>
          </li>
          ${desktop.map(platRow).join('\n          ')}
        </ul>
        <div class="dl__notes">
          <p class="t-card">Android and desktop files come from <a href="${RELEASES}">GitHub Releases</a>. Check a file against <a href="${DOWNLOAD}/SHA256SUMS">SHA256SUMS</a>.</p>
          <p class="t-card">The Android signing certificate fingerprint is published with each release.</p>
          <p class="note t-card">Lectale has no iPhone or iPad app. Open it in Safari or another browser instead.</p>
        </div>
      </div>
      <div class="dl__aside qr">
        <div class="qr__tile"><img src="qr/android.svg" width="164" height="164" alt="QR code for the Android app. The same address is printed below it."></div>
        <p class="qr__label">Android app</p>
        <p class="qr__text t-small">Scan with your phone to download it.</p>
        <p class="qr__url t-mono">${CANONICAL_ANDROID.replace('.dev/', '.dev<wbr>/')}</p>
      </div>
    </div>
  </div>
</section>

<section class="section privacy" aria-labelledby="priv-h">
  <div class="wrap grid">
    <div class="section__head"><h2 class="t-h3" id="priv-h">No tracking</h2></div>
    <div class="section__body">
      <p class="t-card">Lectale has no analytics, advertising or trackers. Opening a course by link reads public repositories only.</p>
      <p><a class="more" href="/privacy/">Read the privacy notice</a></p>
    </div>
  </div>
</section>

</main>
` +
    footer
  );
}

// ---------- catalog.html ----------

function catalogPage() {
  const subjects = [...new Set(COURSES.map((c) => c.subject))].sort();
  const langs = [...new Set(COURSES.map((c) => c.lang))].sort();
  return (
    head({
      title: 'Catalog – Lectale',
      description: 'Browse courses that instructors have listed in the Lectale catalog.',
      script: true,
    }) +
    siteHeader('catalog') +
    `<main id="main" class="catalog">
  <div class="wrap">
    <div class="pagehead">
      <h1 class="t-display t-display--page">Catalog</h1>
      <p class="t-read">Instructors choose to list a course. Everything else can still be opened by its link.</p>
    </div>

    <form class="filters" role="search" aria-label="Search the catalog" data-filter-form action="catalog.html" method="get">
      <div class="field">
        <label class="label" for="q">Search courses</label>
        <input class="input" id="q" name="q" type="search" autocomplete="off">
      </div>
      <div class="field">
        <label class="label" for="lang">Language</label>
        <select class="select" id="lang" name="lang">
          <option value="">All languages</option>
          ${langs.map((l) => `<option>${l}</option>`).join('')}
        </select>
      </div>
      <div class="field">
        <label class="label" for="subject">Subject</label>
        <select class="select" id="subject" name="subject">
          <option value="">All subjects</option>
          ${subjects.map((s) => `<option>${s}</option>`).join('')}
        </select>
      </div>
    </form>

    <div class="results">
      <p aria-live="polite" aria-atomic="true" data-count>${COURSES.length} example courses</p>
      <p>These are examples. They are not real courses.</p>
    </div>

    <ul class="cards" data-cards>
      ${COURSES.map((c) => card(c, { level: 2 })).join('\n      ')}
    </ul>

    <div class="empty" data-empty hidden>
      <h2 class="t-h3" data-empty-title>No courses match</h2>
      <p class="t-card">Check the spelling or search with fewer words.</p>
      <button class="btn btn--outline" type="button" data-clear>Clear search</button>
    </div>
  </div>
  <div class="catalog__body"></div>
</main>
` +
    footer
  );
}

// ---------- Forms: login and create account ----------

const authHead = (title) =>
  head({ title: `${title} – Lectale`, description: `${title} to Lectale.`, noindex: true }) +
  `<header class="appbar"><div class="wrap site__row">${brand()}</div></header>\n`;

const emailField = (value = '') =>
  `<div class="field">
        <label class="label" for="email">Email</label>
        <input class="input" id="email" name="email" type="email" autocomplete="email" inputmode="email" spellcheck="false"${value ? ` value="${value}"` : ''}>
      </div>`;

const pwField = (autocomplete, hint = '') =>
  `<div class="field">
        <label class="label" for="pw">Password</label>
        <div class="control">
          <input class="input" id="pw" name="password" type="password" autocomplete="${autocomplete}"${hint ? ' aria-describedby="pw-hint"' : ''}>
          <button class="reveal" type="button" aria-controls="pw" aria-pressed="false">Show password</button>
        </div>
        ${hint ? `<p class="hint" id="pw-hint">${hint}</p>` : ''}
      </div>`;

function loginPage(state) {
  // The h1 is always first; a notice or an error sits directly under it.
  const notice =
    state === 'expired'
      ? `<div class="alert" role="status">${ICONS.info}<div><p class="alert__title">You’ve been logged out.</p><p class="alert__text">Log in to continue.</p></div></div>`
      : '';
  const err =
    state === 'error'
      ? `<div class="alert alert--error" role="alert" id="login-error">${ICONS.alert}<div><p class="alert__title">The email or password is not correct.</p><p class="alert__text">Check both and try again, or <a href="/app/#/reset-password">reset your password</a>.</p></div></div>`
      : state === 'unconfirmed'
        ? `<div class="alert" role="status" id="login-unconfirmed">${ICONS.info}<div><p class="alert__title">Confirm your email first.</p><p class="alert__text">We sent you a link when you created the account.</p><div class="actions"><button class="btn btn--outline btn--sm" type="button">Send the link again</button></div></div></div>`
        : '';
  const filled = state === 'error' || state === 'unconfirmed' ? 'maria@example.com' : '';
  return (
    authHead('Log in') +
    `<main id="main" class="authpage">
  <div class="wrap">
    <div class="auth">
      <h1 class="t-h2">Log in</h1>
      ${notice}${err}
      <form method="post" action="${APP}">
      ${emailField(filled)}
      ${pwField('current-password')}
      <div class="field"><button class="btn btn--primary btn--lg btn--block" type="submit">Log in</button></div>
      </form>
      <div class="auth__links">
        <p><a href="/app/#/reset-password">Forgot your password?</a></p>
        <p class="alt">No account yet? <a href="create-account.html">Create account</a></p>
      </div>
    </div>
  </div>
</main>
</body>
</html>
`
  );
}

function createPage(sent) {
  if (sent) {
    return (
      authHead('Check your email') +
      `<main id="main" class="authpage">
  <div class="wrap">
    <div class="auth">
      <h1 class="t-h2">Check your email</h1>
      <div class="sent" role="status">
        <p>If <strong>maria@example.com</strong> can be used for a new account, we have sent a link to confirm it.</p>
        <p>If you already have an account, <a href="login.html">log in</a> or <a href="/app/#/reset-password">reset your password</a>.</p>
      </div>
    </div>
  </div>
</main>
</body>
</html>
`
    );
  }
  return (
    authHead('Create account') +
    `<main id="main" class="authpage">
  <div class="wrap">
    <div class="auth">
      <h1 class="t-h2">Create your account</h1>
      <p class="t-read">You need an account to teach, enrol or save courses. You don’t need one to read.</p>
      <form method="post" action="create-account-sent.html">
      ${emailField()}
      ${pwField('new-password', 'Use at least 12 characters. A password you don’t use anywhere else is best.')}
      <p class="t-small t-muted consent">By creating an account you accept the <a href="/terms/">Terms</a> and the <a href="/privacy/">Privacy notice</a>.</p>
      <div class="field"><button class="btn btn--primary btn--lg btn--block" type="submit">Create account</button></div>
      </form>
      <div class="auth__links">
        <p class="alt">Already have an account? <a href="login.html">Log in</a></p>
      </div>
    </div>
  </div>
</main>
</body>
</html>
`
  );
}

// ---------- app-home.html ----------

function appHome({ menuOpen = false, empty = false }) {
  const bar = `<header class="appbar">
  <div class="wrap site__row">
    ${brand()}
    <div class="account">
      <a href="catalog.html">Catalog</a>
      <details class="menu"${menuOpen ? ' open' : ''}>
        <summary><span class="avatar" aria-hidden="true">M</span><span>Maria</span>${ICONS.down}<span class="vh"> account menu</span></summary>
        <div class="menu__panel">
          <p class="menu__who">Signed in as maria@example.com</p>
          <button class="menu__item" type="button">Log out</button>
          <button class="menu__item" type="button">Log out of all devices</button>
        </div>
      </details>
    </div>
  </div>
</header>
`;

  const openForm = (primary) => `<form class="stack" method="get" action="${APP}">
          <div class="field">
            <label class="label" for="repo">GitHub repository address</label>
            <input class="input" id="repo" name="repo" type="url" inputmode="url" autocomplete="off" spellcheck="false" aria-describedby="repo-hint"${primary ? ' autofocus' : ''}>
            <p class="hint" id="repo-hint">For example, https://github.com/owner/repository</p>
          </div>
          <div class="actions"><button class="btn ${primary ? 'btn--primary btn--lg' : 'btn--outline'}" type="submit">Open course</button>${primary ? '<a class="btn btn--outline btn--lg" href="catalog.html">Browse the catalog</a>' : ''}</div>
        </form>`;

  if (empty) {
    return (
      head({ title: 'Home – Lectale', description: 'Your Lectale home.', noindex: true }) +
      bar +
      `<main id="main" class="home">
  <div class="wrap">
    <h1 class="t-h2">Hello.</h1>
    <section class="empty-home" aria-labelledby="empty-h">
      <h2 class="t-h3" id="empty-h">You have no courses yet</h2>
      <p class="t-read">Open a course with its link, or browse the catalog.</p>
      <p class="t-card t-muted">Any public GitHub repository with a course.yaml file. No account needed; Lectale only reads it.</p>
      ${openForm(true)}
    </section>
  </div>
</main>
</body>
</html>
`
    );
  }

  const byId = Object.fromEntries(COURSES.map((c) => [c.slug, c]));
  const mine = [
    [byId['introduction-to-statistics'], 'You teach this course. Listed in the catalog.'],
    [byId['python-for-lab-data'], 'You teach this course. Unlisted.'],
  ];

  return (
    head({ title: 'Home – Lectale', description: 'Your Lectale home.', noindex: true }) +
    bar +
    `<main id="main" class="home">
  <div class="wrap grid">
    <div class="home__main">
      <h1 class="t-h2">Hello, Maria.</h1>

      <section aria-labelledby="cont-h">
        <h2 class="t-h3" id="cont-h">Continue reading</h2>
        <div class="cont">
          <img class="cover" src="covers/introduction-to-statistics.svg" width="480" height="720" alt="" decoding="async">
          <div>
            <p class="cont__title">Introduction to statistics</p>
            <div class="cont__place">
              <span class="ribbon" aria-hidden="true"></span>
              <p id="cont-lesson">Averages and spread<br><span class="t-small t-muted">Describing data. Last opened lesson.</span></p>
            </div>
            <a class="btn btn--primary btn--lg" href="${APP}" aria-describedby="cont-lesson">Continue</a>
          </div>
        </div>
      </section>

      <section aria-labelledby="mine-h">
        <h2 class="t-h3" id="mine-h">Your courses</h2>
        <ul class="mine">
          ${mine
            .map(
              ([c, status]) => `<li>
            <img class="cover" src="covers/${c.slug}.svg" width="480" height="720" alt="" loading="lazy" decoding="async">
            <div><a href="${APP}">${c.title}</a><p class="t-small">${status}</p></div>
          </li>`,
            )
            .join('\n          ')}
        </ul>
        <p class="t-card teach">Teaching a course? Connect its repository to manage it.</p>
        <p><a class="more" href="${APP}">Connect a repository</a></p>
      </section>
    </div>

    <aside class="home__side" aria-labelledby="open-h">
      <div class="sidebox">
        <h2 class="t-h3" id="open-h">Open a course from GitHub</h2>
        <p class="t-card">Any public GitHub repository with a course.yaml file. No account needed; Lectale only reads it.</p>
        ${openForm(false)}
      </div>
    </aside>
  </div>
</main>
</body>
</html>
`
  );
}

// ---------- Write ----------

copyFileSync(join(here, '..', '..', 'brand', 'logo-01-ribbon-cut-mulberry.svg'), join(here, 'logo.svg'));

out('index.html', indexPage());
out('catalog.html', catalogPage());
out('login.html', loginPage('default'));
out('login-error.html', loginPage('error'));
out('login-unconfirmed.html', loginPage('unconfirmed'));
out('login-expired.html', loginPage('expired'));
out('create-account.html', createPage(false));
out('create-account-sent.html', createPage(true));
out('app-home.html', appHome({}));
out('app-home-menu.html', appHome({ menuOpen: true }));
out('app-home-empty.html', appHome({ empty: true }));
console.log('built');
