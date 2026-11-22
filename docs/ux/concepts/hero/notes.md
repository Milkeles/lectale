# Lectale hero studies

Each desktop study is 1440 × 900. The two finalists also have a 390 × 844 phone view and a 1440 × 900 dark view. All five share the supplied navigation, headline, subheading, buttons, and statistics reader beneath the hero. I used the supplied Lectale mark and the project’s Source Serif 4 and IBM Plex Sans fonts.

The artwork was made with the built-in image generation tool. Chromium could not start in the workspace, so the PNGs are composited website mockups. I typeset the interface copy and the excerpts from `quotes.md` directly over text-free artwork. The strokes on the illustrated papers represent type or code texture. The files show still frames, with interaction and motion described below.

## A · Quote orbit

Four quotations take up different points on two fine elliptical rules around an engraved open book. The upright cards give each author a place to read while the small bookmark carries the eye to the course preview.

- **HTML and CSS.** Use an ordered group of figures with `blockquote` and `figcaption`, two CSS ellipses, and a transparent book image. Keep the DOM reading order stable and expose a static list at narrow widths or high zoom.
- **Motion and access.** Move the cards a short distance back and forth along their respective arcs with CSS transforms. Keep each card upright, pause on pointer hover or keyboard focus, and give the visible pause button a keyboard-operable toggle with an accessible label. Use the resting layout for `prefers-reduced-motion`.
- **Risk.** The extracts can compete with the call to action. Full revolutions would also make it harder to resume a quote, so the cards should stay within well-spaced sectors. Test long translations before enabling movement.

## B · Margins

A sample histogram lesson fills one side of an open folio, with four reader’s notes facing it. Thin leader lines and the binding make the quotations feel like thoughts in the margin of a course someone is already reading.

- **HTML and CSS.** Set the lesson, chart description, four quotes, and full credits in HTML. A generated blank folio supplies the paper and binding. CSS rules draw the leaders and histogram bars. The phone view gives one note room on the facing page and puts the other three in a native **More notes** disclosure.
- **Motion and access.** Keep the spread still. The mobile disclosure opens on request and needs no transition. Where the spread can no longer keep comfortable text sizes, let the lesson and notes stack in reading order. Use a charcoal treatment for the paper in dark mode and keep the ink color independent.
- **Risk.** At large text sizes the fixed spread can run out of space. The sample chart should be described alongside the lesson, and the notes should link to their sources if this direction ships.

## C · Ribbon

A long woven bookmark descends from the browser edge beside **Make a course**. Across the hero, one Thoreau excerpt gives the left-hand gesture a quiet counterpart.

- **HTML and CSS.** Use a transparent narrow ribbon image anchored to the left gutter and trim its visible length to the CTA row. The quote and credit are real text and the fine rules are CSS.
- **Motion and access.** Keep the ribbon static and out of the navigation and button hit areas. Give it empty alt text since the adjacent content carries the meaning.
- **Risk.** The ribbon depends on having a gutter. A narrower viewport needs a shorter ribbon or more space above the buttons, and the sparse right side may still feel too quiet to the owner.

## D · Gathering

A PDF, notebook, video, code printout, and slide form a still life above the reader. The front two pieces disappear behind the reader frame, showing how the separate materials become one course.

- **HTML and CSS.** Place one generated transparent composition behind the real course preview with CSS stacking. Use HTML for the format labels and the reader. Give the composite a short description if the format labels are hidden at a breakpoint.
- **Motion and access.** Keep the materials still and let the overlap imply the direction of travel. The illustrated play triangle belongs to the art and carries no tab stop.
- **Risk.** The material types need to remain recognizable when the image shrinks. The printed video frame could be mistaken for a playable control if the illustration sits too close to interactive UI.

## E · The Index

A hand-bound course index gives the statistics materials a single physical form, with stepped paper, mulberry tabs, and a gold place marker. The course name above it and the actual reader below connect the object to what a shared Lectale link opens.

- **HTML and CSS.** Use a responsive figure with a live course title and a compact list of formats. The tabbed book is `asset-course-index.png`, a transparent 1120 × 630 PNG for a 560 × 315 desktop display. Scale the same asset to fit the phone and apply the darker treatment to the image independently of the title and format labels.
- **Motion and access.** Keep the book still. Use one short alt description for the image and omit the faux tab shapes from the tab order. The headings, links, buttons, and format labels remain live text in the site implementation.
- **Risk.** The book can suggest printed material by itself, so the media labels and the nearby reader do important work. Keep enough tonal separation between the mulberry tabs and the dark panel.

<details>
<summary>Image generation prompts</summary>

**A.** Use case: illustration-story. Generate a premium transparent editorial illustration to occupy the center of an orbit of quotes on the Lectale learning website. Art only, no text/lettering/UI. An open hardback book seen at a very slight oblique front angle, almost a heraldic open-book silhouette, with compact cream and pale taupe printed pages and a muted mulberry cloth cover, thin graphite ink details with hand-engraved hatching; a small gold ochre #905E0C woven notched book ribbon falls down from its center spine. High-end contemporary literary journal woodcut crossed with restrained midcentury book plates. No extra shapes, extra colors or accessories. Keep the subject centered, fully in frame, with an airy and compact silhoutte, unobstructed and designed to read when shrunk to 195px. Alpha background, no paper backdrop, no backdrop shadows. Wide 3:2 framing.

**B.** Use case: illustration-story. Generate the art for Lectale's 'Margins' desktop hero, a precise overhead scan of ONE open study folio spread with sewn binding in the center, two pristine blank ivory pages, and a very thin dark mulberry cloth edge. The two pages span most of the image, squared almost to the camera and genuinely flat enough to overlay clean HTML text and margin notes afterward. Generous uninterrupted writing areas on both pages and only faint page wear. Refined modern academic editorial art direction, tactile real paper and faint natural binding shadow. True transparent outside the silhouette, no other objects, no type, no symbols, no ruling, no letters, no handwriting, no decorative borders. The folio ratio is about 1.62:1, framed as wide as possible with even minimal breathing room.

**C.** Use case: product-mockup. Generate the sole artwork for the minimalist Lectale 'Ribbon' landing hero. A single elongated woven ochre gold bookmark ribbon #905E0C, drops from just beyond the top edge and ends in a small flat traditional V-cut tail fully visible close to the bottom. It is seen face on, only a slight graceful sideways bend and restrained fabric folds. The ribbon has fine matte herringbone weave and one short curl of reverse-side muted ochre, hand-crafted bookbinding, absolutely no bow, no loop, no gloss, no book, no gold elsewhere, no text, no cast backdrop or outside setting. Actual transparent background. Tall portrait image, ribbon is very slim, centered in the image, 8–13 percent of frame width. Clean strong silhouette suitable to place between editorial text columns.

**D.** Use case: photorealistic-natural. Generate the artwork for a high-end education company landing page 'Gathering'. Art only. A carefully composed overhead editorial still life of exactly five course materials arranged in a tight overlapping, descending fan that narrows toward the bottom edge at center, where a real HTML Lectale reading window will start. The items must be immediately legible by shape: ivory print/PDF sheet with a single graphite bar chart on upper left; dot grid computational notebook page with a simple mulberry line chart across the upper center; film-frame lecture video on upper right showing an empty classroom chalkboard with chalk histogram, no people; one cream narrow source-code printout with quiet indented graphite and mulberry code-like strokes at lower left; a landscape lecture slide with two graphite diagrams at lower right. Sumptuous uncoated paper texture, precise shadows over objects only, occasional mulberry keylines, cool graphite grayscale and warm white. Front-facing almost top-down, minimal perspective, visually grounded like a carefully styled uni press print catalog. Asymmetrical fan offset, extremely refined edges. No legible letters, no logos, no background or beyond-object soft shadow, no gold, no glossy effects. Transparent cutout, wide landscape frame with artwork filling nearly the whole width.

**E.** Use case: illustration-story. Generate a hero illustration for Lectale called 'The Index'. Create a macro editorial cutout of ONE especially beautiful hand-bound course index with ivoried, micro-ruled stock, open as a three-quarter stepped opening toward camera. It reads as an inviting physical card index crossed with a book, arranged from bottom left to top right. 4 distinct progressively stepped page edges with generously sized permanent rectangular (not fishtail) mulberry cloth index tabs coming off the right edges, and a single muted gold #905E0C woven bookmark with a cut-out notch lying between two sheets and falling over the front bottom edge. Layered deckled cream paper, blind embossed hairline rules, graphite typographic texture rendered only as horizontal strokes, and a small elegant graphite halftone line chart on upper face. Refined contemporary independent academic publishing, tactile and elegant. Graphite, warm paper, and mulberry are the dominant notes. Hero object isolated on genuine alpha background, no extra objects, no floor or cast shadow outside the book, no legible text or logos, no modern tech gradients. Wide composition with all edges and tab ends in frame. Book is substantial but airy, photographed in soft indirect daylight.

</details>

## Ranking

1. **E · The Index.** The bookmark and tabs give Lectale a recognizable image, and the composition holds up on a phone. This is favourite 1 and the source of the reusable asset.
2. **B · Margins.** The quotations feel at home beside something the visitor can read. This is favourite 2 and the strongest direction if the quotes are central to the brief.
3. **D · Gathering.** The overlap makes the product promise concrete, though the five materials ask for more attention at once.
4. **A · Quote orbit.** The orbit is distinctive and honors the owner’s suggestion. Its movement and longer extracts take the most work to keep easy to read.
5. **C · Ribbon.** The gold accent gives the CTA a recognizable companion, but a single ribbon and quote still leave the hero comparatively sparse.
