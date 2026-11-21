# Brief: Lectale's landing page and app entry, concept round

| | |
|---|---|
| **Status** | Concept. Nothing here is built until the owner approves the concept. |
| **Owner of this brief** | Orchestrator (main session) |
| **Date** | 2026-11-21 |

## Why this round exists

The owner reviewed the deployed Home screen and three Codex concepts and turned all of them down. In the owner's words, the design "doesn't read polished and high quality", "there is no hook", and "you can't tell where you ended up": the page says to open a GitHub repository but never says what Lectale is. The owner asked for "a standard landing page" that stays accessible and doesn't look AI-generated, which "doesn't mean make it ugly or boring". It should be clean, with no mental overload, but with better typography, better copy and a better-thought-out set of contents.

What the owner wants on it:

- what Lectale is, said in a way that hooks a first-time visitor;
- navigation with **Log in** and **Create account** (instructors need accounts to create and manage courses);
- **download links for each platform**, **QR codes** for phones, and an option to **use it on the web**;
- the **catalog** has a place;
- courses show **thumbnails**.

The earlier rule "Home is a form on the start line, no hero" (`docs/ux/screens/home.md`) is withdrawn. A real landing page with a hero is expected. The anti-generic rules still hold: no gradient blobs, stock people, three identical feature cards, fake numbers or testimonials, emoji, or eyebrow labels in capitals.

## Fixed decisions (don't reopen)

- **Colour** (`docs/ux/token-plan.md`): warm grey Paper `#F4F1ED` (dark `#191B1A`), Sand `#E8E3DC` (dark `#262927`), Graphite text `#242725` (dark `#E9E5DE`).
  - Mulberry `#753E5E` (dark `#E0A7C0`) is the brand colour: logo, links, titles.
  - Gold `#905E0C` (dark `#F3DDA4`) is the one accent, used only for the primary call to action, the bookmark ribbon and the focus ring.
  - Paper, graphite and mulberry are about 80 percent of what is seen.
- **Type:** Source Serif 4 for reading text and display headings (ADR-0012), IBM Plex Sans for interface text, IBM Plex Mono for code.
- **Brand:** the Ribbon Cut logo, mulberry (`docs/ux/brand/`); the wordmark reads "Lectale", capitalised. The swallowtail ribbon is the memorable element.
- **Accessibility:** WCAG 2.2 AA. Everything works by keyboard, focus is always visible, and motion respects reduced-motion settings.
- **Privacy:** no analytics, trackers or third-party embeds on the site (spec `docs/EU_PRIVACY_COOKIES.md`; V4-COST-06), so there is no cookie banner.
- **Distribution:**
  - GitHub Releases for Android (APK), Windows, macOS and Linux, plus the web app.
  - **No iOS build is available**, because there is no Apple account; the honest message for iPhone and iPad users is "use Lectale in your browser".
  - No store listings yet.

## Product facts the concept must respect (from the spec)

- **Reading needs no account.** Anyone can open a public GitHub course by its link (V4-CORE-01, V4-CORE-02).
- **Accounts are for instructors and enrolled learners.** They are the sign-in milestone (M3), managed courses (M4) and enrolment (M5). Sign-in uses Firebase Auth (ADR in `docs/adr/`).
- **The catalog is optional.** Courses are listed only when their owner opts in, and a new managed course starts unlisted (V4-CAT-01 to V4-CAT-05, `docs/CORE_EXPERIENCE_AND_CATALOG.md`). Opening by link must keep working when the catalog is down.
- **Thumbnails:** `course.yaml` v3 already has `course.cover`, a repository-relative image path. It becomes the course thumbnail. No schema change is needed.
- **Paid courses are off for now (M9).** Don't advertise prices.

## Open architecture question

Should the public landing page be a static HTML and CSS page served by the Worker, with the Flutter app at `/app`, instead of being drawn by Flutter web? The considerations are search indexing, first-load speed, accessibility and link previews. The researcher answers from Flutter's own documentation. The docs-pm records the decision as an ADR. The native apps open straight into the app, not the landing page.

## Who does what

| Step | Agent | Output |
|---|---|---|
| 1 | researcher | `docs/research/2026-11-21-landing-references.md`: landing pages of comparable products (structure, hook, how downloads and QR codes are shown), the Flutter web suitability facts, QR code generation options, homepage-clarity guidance |
| 1 | copywriter | `docs/ux/copy/landing.md`: positioning, two or three hook options, all landing copy, navigation labels, download section, sign-in and account copy, catalog teaser |
| 2 | frontend-engineer (design lead) | Site map and screen specs (`docs/ux/screens/landing.md` and the app's signed-in home); the landing concept built as static HTML and CSS in `docs/ux/concepts/landing/` with the real fonts, colours, logo, thumbnails and QR codes; screenshots at 1440 and 390 px, light and dark |
| 2 | security-reviewer | Review of the sign-in and account flows in the specs: no credentials in browser storage, account-enumeration-safe messages, what the landing page may load |
| 3 | design-reviewer, then Codex | A ledger of fixes from the screenshots plus an axe-core run on the HTML; one round of fixes by the design lead |
| 3 | docs-pm | ADR for the website architecture |
| 4 | Orchestrator | Present the concept to the owner |
