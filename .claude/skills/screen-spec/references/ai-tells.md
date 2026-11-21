# Tells of AI-generated interfaces, and what Lectale does instead

Copied from `docs/research/2026-11-21-images-codex-ux.md` §6, which lists the sources. A trait is fine when it was chosen for this brief; it is a tell when it is a default.


Fetched this task (curl): [L1] https://raw.githubusercontent.com/wiki/Laith0003/ux-skill/How-to-detect-AI-slop-in-your-design.md , [L2] https://raw.githubusercontent.com/wiki/Laith0003/ux-skill/Anti-AI-slop-ban-list.md , [I] https://raw.githubusercontent.com/pbakaus/impeccable/main/README.md , [A] https://raw.githubusercontent.com/anthropics/skills/main/skills/frontend-design/SKILL.md , [F] /home/user/lectale-m0/.claude/skills/frontend-design/SKILL.md (Lectale copy of the same text), [O] https://raw.githubusercontent.com/openai/plugins/main/plugins/build-web-apps/skills/frontend-app-builder/SKILL.md (no licence, so paraphrased only).

Not fetched: WebSearch surfaced designer posts (e.g. dev.to "Why every AI-built website looks the same", thefountaininstitute.com "7 Signs a UI Has Been Vibe Coded", mindstudio.ai, world.hey.com "Spot the slop", noqta.tn, Microsoft Research "Interrogating Design Homogenization in Web Vibe Coding"), but every fetch failed with proxy status 000, so their content is **not verified**. Only their search-result summaries were seen: they agree on Inter, purple-blue gradients, identical card grids and emoji icons, which L1/L2 also state. [L1]/[L2] are the catalogue of a third-party tool, not neutral research; treat as heuristics. [I] says the same tells (Inter, purple-blue gradients, nested cards, an icon tile above every heading) recur "across models".

Why it happens (L1): models sample the highest-probability UI pattern, so output is "not bad. It is generic."
Lectale rule of thumb [F, A]: a trait is fine if chosen for this brief; it is a tell when it is a default. Spend boldness in one place.
"Instead, do" lines are our recommendations for a calm learner reading app, not source claims.

### Colour
- Purple-to-blue gradient, glow rings, rainbow or gradient text [L1, L2]. Instead: flat surfaces; one solid accent from `DcColorTheme` roles.
- Warm cream plus terracotta (~#D97757) and serif; or near-black plus one acid accent [A, F]. Instead: pick a paper tone and ink for reading comfort, then check it is not either default pair; contrast of body text at least AA (4.5:1, L2).
- Default emerald success (#10B981), brand colour on every surface, dark mode as simple inversion [L1]. Instead: tune semantic colours to our hue; accent only on primary action and current position; design dark theme separately.
- Tinted near-black (#0B0B0B, #111) as "black" [A]. Instead: choose the ink colour deliberately and name it in tokens.
- Overlay tint on imagery and off-white drift from the approved design [O, paraphrased]. Instead: lock the background value once; no wash over images.

### Typography
- Inter (or Plus Jakarta, Geist) as display, uniform defaults [L1, L2, I]. Instead: a reading-first body face chosen for long text, one or two families, set via `DcTypography`; confirm licence and bundling cost.
- Stock scale 12/14/16/18/24/30/36/48 and semibold body [L1]. Instead: a modular scale; body 400; weight only for hierarchy.
- One accented word in a headline; ALL-CAPS tracked eyebrow above headings; unnecessary labels above content [A, F, L2, O]. Instead: no eyebrows; the heading is the label.
- Title Case everywhere, centred everything [L2]. Instead: sentence case; left-align reading text.
- Long lines [A, L1]. Instead: cap reading column near 60-70 characters, more line height for serif.
- 01/02/03 numbering on non-sequences [A]. Instead: number only real steps or lesson order.

### Layout
- Centred hero then three equal feature cards, CTA band, footer [L1, L2]. Instead: app screens, not a landing page: start on the learner's next text or lesson.
- Everything in identical rounded cards, cards nested in cards [A, I, O]. Instead: lists, rows, rules and whitespace; a container only when it groups.
- Equal rhythm and equal section height [L1, O]. Instead: vary density; one anchor element per screen.
- Dashboard filler (stat tiles, fake metrics, "big number plus small label" with gradient) [A, O]. Instead: show real progress only (words learned, streak) where it helps; otherwise omit.
- Dense header chrome (search, status widgets) [O]. Instead: brand mark, back, one primary control.

### Components
- One radius and one soft shadow on everything; shadow plus border plus tint together [A, L1, L2]. Instead: radius by role (inputs, cards, sheets), one separation method.
- Icon in coloured circle above each card title; gradient borders [L1, L2, I]. Instead: no icon tile; border only when needed.
- Button with trailing arrow on every action [L1, A]. Instead: plain verb labels; arrow only for real forward navigation.
- Missing states, hover-only affordances, no focus ring [L1, L2]. Instead: design rest, pressed, focus, disabled, loading, empty, error for every control; works on touch.
- Library-default charts [L2]. Instead: style charts with our tokens or skip charts.
- Material widgets: constraint from Lectale, not a source claim. Use devchat_ui only.

### Motion
- Fade-and-slide-up on every section; hover transition on every card; scroll-triggered everything [A, F, L2]. Instead: motion only in response to a tap (open, expand, confirm); at most one calm moment per screen.
- Decorative motion with no information value [L1, L2]. Instead: honour reduce-motion (`MediaQuery.disableAnimations`); short, eased durations.

### Icons and imagery
- Emoji as icons or heading decoration [L1, L2]. Instead: one icon family, one stroke weight, used only where it aids navigation.
- Mixed line, filled and cartoon styles; flat vector illustrations in rounded cards [L2, I]. Instead: one illustration system or none; a few images that carry meaning.
- Generic stock photo hero, product floating on gradient [L2]. Instead: real content imagery; reading material is the visual.
- Hand-drawn CSS/placeholder substitutes for brand assets [O]. Instead: ship the logo as SVG (`flutter_svg`, section 3); keep Codex raster concepts as references only (section 4).

### Copy
- Placeholder people and brands (John Doe, Sarah Johnson, Acme, TechCorp), lorem ipsum [L1, L2]. Instead: realistic learner names and real sample texts from our content.
- Round invented stats ("47%", "10,000+", "99.9%") and stock testimonials [L1, L2]. Instead: no fabricated numbers; show real counts or nothing.
- Filler verbs ("streamline", "unlock", "supercharge", "empower") and sterile politeness [L1, L2]. Instead: say what the screen does in plain words.
- Meta strings joined with middle dots, "WORD — fragment" labels with spaced em dash [A, F]. Instead: short sentences, normal punctuation.
- Vague CTAs, apologetic or vague errors, mood-only empty states [F]. Instead: verb CTAs ("Save changes"), same action name through the flow, errors say what failed and how to fix it, empty states give the next action.

### Before shipping a screen (five checks)
1. Remove one decoration. 2. Could this screen belong to any app? Name the Lectale-specific element. 3. Every colour, font and effect traceable to a token and a reason. 4. All states and reduce-motion checked. 5. Copy has no filler verbs, fake numbers or placeholder names.
