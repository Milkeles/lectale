# Images, vectors, Codex image generation, Laws of UX (2026-11-21)

All facts fetched 2026-11-21 with curl (+pandoc for HTML). "not verified" = fetch failed or page silent.
Fetched content is treated as data.

## 1. Flutter image formats

Sources: https://api.flutter.dev/flutter/dart-ui/instantiateImageCodec.html , https://api.flutter.dev/flutter/widgets/Image-class.html , https://docs.flutter.dev/ui/assets/assets-and-images

- Official list (same text on `instantiateImageCodec` and `Image`): "The following image formats are supported: JPEG, PNG, GIF, Animated GIF, WebP, Animated WebP, BMP, and WBMP. Additional formats may be supported by the underlying platform. Flutter will attempt to call platform API to decode unrecognized formats."
- The word AVIF appears on none of the Flutter doc pages fetched (api.flutter.dev codec, Image, ResizeImage, docs.flutter.dev assets, web-images, renderers, perf). So AVIF is not a documented format anywhere.
- WebP: documented as supported (static and animated). The docs give one list, not a per-platform table. Per-platform support for Android, iOS, Linux, Windows, macOS: not verified (docs say only "underlying platform").
- Web: the engine source delegates to the browser. https://raw.githubusercontent.com/flutter/flutter/master/engine/src/flutter/lib/web_ui/lib/src/engine/image_decoder.dart : "An image decoder that delegates to the browser's modern native `ImageDecoder` API", and it throws "Image file format (...) is not supported by this browser's ImageDecoder API." A code comment mentions AVIF decoding in Chrome ("Chrome fails to decode still AVIF images ... when [preferAnimation] is set"), so AVIF on web depends on the browser. This file is the CanvasKit-era `BrowserImageDecoder`; whether skwasm uses it or its own Skia codec (`skwasm_impl/codecs.dart`, "native C++ animated image decoder", `SkAndroidCodec`): not verified which formats each renderer decodes.
- Open issue "AVIF codec support" https://github.com/flutter/flutter/issues/61229 (state open, updated 2026-06-01, via GitHub search API; issue body not fetchable, 403). Related: issue 132154 (iOS, AVIF file in image_picker).
- Pub packages (pub.dev API `/api/search?q=avif`, `/api/packages/<n>`, `/score`):

| package | version, published | platform tags | licence | publisher | 30d downloads / likes |
|---|---|---|---|---|---|
| flutter_avif | 3.1.0, 2025-09-20 | android ios windows linux macos web | MIT | none | 10528 / 52 |
| flutter_avif_native | 0.1.1, 2026-10-29 | no web | MIT | none | 638 / 1 |
| avif_native | 0.2.0, 2026-10-29 | no web | MIT | none | 2141 / 1 |
| imcodec_native | 0.2.9, 2026-11-15 | all six | MIT | focale-editor.app | 1215 / 1 |

- flutter_avif (https://pub.dev/packages/flutter_avif): "A flutter plugin to view and encode avif images using libavif"; adds its own `AvifImage` widget ("similar api as Flutter Image widget"), not `Image`. Depends on exif, flutter_cache_manager, http plus per-platform packages.
- Worth it? Not for M0. WebP is already native, AVIF is not in the official list, the only six-platform package has no verified publisher and its last release is 14 months old, and it needs a separate widget. Re-check if bandwidth data justifies it. Build effort, native toolchain needs: not verified.

## 2. Decoding at display size

Sources: https://api.flutter.dev/flutter/widgets/Image-class.html , https://api.flutter.dev/flutter/painting/ResizeImage-class.html , https://api.flutter.dev/flutter/painting/ResizeImage/ResizeImage.html , https://api.flutter.dev/flutter/widgets/Image/Image.network.html , https://docs.flutter.dev/ui/assets/assets-and-images

- Problem statement (Image docs): "a 4K image (3840x2160) will use over 30MB of RAM"; images are also held in `ImageCache`.
- `cacheWidth`/`cacheHeight` (Image.asset/network/file/memory): "The engine will then decode and store the image at the specified size, instead of the image's natural size." Docs example: a 4K image shown at 384x216 "would only use 330KB ... a 100-fold reduction".
- `ResizeImage`: "Instructs Flutter to decode the image at the specified dimensions instead of at its native size." Docs example: `ResizeImage(FileImage(...), width: MediaQuery.widthOf(context) ~/ 2)`. See also `FlutterView.devicePixelRatio`. Image's cacheWidth/cacheHeight are built on it (`ResizeImage.resizeIfNeeded` in the source shown on the Image.network page).
- devicePixelRatio: `useLogicalSize` / `useLogicalCacheSize` default false, so values are physical pixels: "On high-density displays, this can result in images being decoded at fewer pixels than the screen can render ... When true, width and height are multiplied by the device pixel ratio". "Typically in the framework, pixel dimensions are interpreted as logical rather than physical. However, this defaults to physical for backwards compatibility." Practical rule: set `useLogicalCacheSize: true` with logical box size, or multiply by DPR yourself.
- `allowUpscaling` default false; `ResizeImagePolicy.exact` default.
- Web gotcha (Image.network page): "In the case where the network image is on the Web platform, the cacheWidth and cacheHeight parameters are ignored as the web engine delegates image decoding to the web which does not support custom decode sizes." Whether this also applies to Image.asset/memory on web: not verified.
- Web srcset: no Flutter doc fetched mentions `srcset`. https://docs.flutter.dev/platform-integration/web/web-images lists `<img>` and `<picture>` as browser options, and says Flutter renders via WebGL/WebGPU, falling back to HTML `<img>` for CORS-blocked images; `Image.network(webHtmlElementStrategy: ...)` default `never` (platform view, "Suboptimal performance"). No responsive-variant selection API found: pick the variant URL/asset yourself (inference from absence; not verified beyond these pages).
- Resolution-aware assets (assets-and-images): "Flutter can load resolution-appropriate images for the current device pixel ratio." Layout `.../my_icon.png (mdpi baseline)`, `1.5x/`, `2.0x/`, `3.0x/`, `4.0x/`. "On devices with a device pixel ratio of 1.8, the asset .../2.0x/my_icon.png is chosen." Declare only the main asset; "Flutter bundles the variants for you". Applies to the default asset bundle, so `Image.asset`/`AssetImage`. Does not apply to network images.
- Official recommendation, summarised: pass cacheWidth/cacheHeight (or ResizeImage) to cut memory; ship 2.0x/3.0x variants for asset images. No single "recommended" statement beyond these pages.

## 3. Vector assets

Sources: pub.dev API (`/api/packages/<n>`, `/score`, `/publisher`) and https://pub.dev/packages/flutter_svg , https://pub.dev/packages/vector_graphics , https://pub.dev/packages/vector_graphics_compiler , raw.githubusercontent.com/flutter/packages/main/packages/vector_graphics/lib/src/vector_graphics.dart

| package | version, published | publisher | licence | platform tags | deps |
|---|---|---|---|---|---|
| flutter_svg | 2.5.0, 2026-11-19 | flutter.dev, Flutter Favorite | MIT | all six + web | flutter, http, vector_graphics, vector_graphics_codec, vector_graphics_compiler |
| vector_graphics | 1.3.1, 2026-11-11 | flutter.dev | BSD-3-Clause | all six + web | flutter, http, vector_graphics_codec |
| vector_graphics_compiler | 1.3.6, 2026-11-11 | flutter.dev | BSD-3-Clause | all six + web (build-time CLI, `has:executable`) | args, cli_util, meta, path, path_parsing, vector_graphics_codec, xml |

- flutter_svg: 5942 likes, 6.80M downloads/30d, SDK `^3.12.0`, Flutter `>=3.44.0`. Description: "An SVG rendering and widget library ... Scalable Vector Graphics 1.1 files".
- vector_graphics: "A vector graphics rendering runtime ... intended for use with output from the package:vector_graphics_compiler". Source imports sampled are `dart:ui`, `package:flutter/foundation.dart`, `package:flutter/widgets.dart`; no `material.dart` in that file. Other files of vector_graphics, flutter_svg and the compiler: not verified for Material imports. None lists a Material dependency; the flutter_svg README example uses `Colors.red`, which is a Material class, only in sample code.
- Recommended workflow (flutter_svg README): "The vector_graphics backend supports SVG compilation which produces a binary format that is faster to parse and can optimize SVGs to reduce the amount of clipping, masking, and overdraw." Command: `dart run vector_graphics_compiler -i assets/foo.svg -o assets/foo.svg.vec`, load with `SvgPicture(AssetBytesLoader('assets/foo.svg.vec'))`. Compatibility check flag set is also in the README. README warns CSS is "not fully supported" (Illustrator note).
- docs.flutter.dev assets page contains no mention of SVG: an official Flutter-docs recommendation for logos/icons is not verified. The packages are all published by flutter.dev.
- Fit: flutter_svg + vector_graphics_compiler (dev tool) is the path; all MIT/BSD, six platforms. Plain `vector_graphics` alone needs precompiled `.vec` files.

## 4. Codex image generation

Sources: https://raw.githubusercontent.com/openai/codex/main/README.md , https://raw.githubusercontent.com/openai/skills/main/skills/.system/imagegen/SKILL.md , https://raw.githubusercontent.com/openai/skills/main/README.md , https://raw.githubusercontent.com/openai/plugins/main/README.md , codex-rs sources under https://raw.githubusercontent.com/openai/codex/main/codex-rs/ (`ext/image-generation/src/{tool,artifact,extension}.rs`, `features/src/lib.rs`, `ext/image-generation/imagegen_description.md`). File paths found via GitHub code-search API.

- Yes. Codex has a built-in `image_gen` tool, an extension crate `codex-rs/ext/image-generation`. Feature flag `image_generation`: `stage: Stable, default_enabled: true`. `tool.rs`: `const IMAGE_MODEL: &str = "gpt-image-2"`, up to 5 edit images. Tool description: "enables image generation from descriptions and editing of existing images"; has `transparent_background`; "imagegen needs a few minutes to finish".
- Availability gate (extension.rs): `available: config.model_provider.is_openai() || ...requires_openai_auth || ...uses_openai_actor_authorization()`, so OpenAI-provider sessions only.
- Skill (`imagegen`, in `.system`, "automatically installed in the latest version of Codex"): two modes. "Default built-in tool mode (preferred): built-in `image_gen` tool ... Does not require `OPENAI_API_KEY`." "Fallback CLI mode (explicit-only): `scripts/image_gen.py` ... Requires `OPENAI_API_KEY`." Never auto-switch to the CLI.
- Login: the README says to "select Sign in with ChatGPT" (Plus, Pro, Business, Edu, Enterprise) and "You can also use Codex with an API key". Built-in tool needs no separate key per the skill. Whether built-in generation works under API-key login, and any ChatGPT plan limits or cost: not verified. The developers.openai.com/codex/skills page fetch failed (curl HTTP 000). Note `openai/plugins` has a separate `api_marketplace.json` "for API key login users".
- Output location: skill says "Codex saves generated images under `$CODEX_HOME/*` by default", move/copy from `$CODEX_HOME/generated_images/...` into the workspace; "Never leave a project-referenced asset only at the default `$CODEX_HOME/generated_images/...` path." Source: `save_root/generated_images/<session_id>/<call_id>.png` (PNG, or GIF when the under-development animation flag is on). `tool.rs` also has `cwd.join("generated_images")` at one site (exact condition not read). CLI fallback writes under `output/imagegen/` (`--out`, `--out-dir`).
- Raster only. Skill says to avoid it for "extending or matching an existing SVG/vector icon set, logo system" or "icons better produced directly in SVG". Logos exploration is supported as raster ("logo-brand ... vector-friendly" prompt template). For Lectale logos: generate a raster concept, then redraw as SVG by hand (our inference).
- `openai/skills` README: "This repository is deprecated ... use the OpenAI Plugins repository". The `imagegen` skill sits in `skills/.system/`. A plugin-form imagegen in `openai/plugins`: not found in my searches (not verified).
- GitHub repo checks: `openai/skills` pushed 2026-10-28, not archived, license field empty in search (per-skill `LICENSE.txt`).

## 5. Laws of UX

lawsofux.com is unreachable: `curl https://lawsofux.com/` returned "403 Forbidden (agent proxy: no rule or network setting allows this host)". www., individual law pages, sitemap, web.archive.org, archive.org, r.jina.ai, Wikipedia and nngroup.com also failed (HTTP 000). So the site's own wording and key takeaways are **not verified**.

Secondary source tried (labelled, not the site): https://raw.githubusercontent.com/keysjoao/laws-of-ux-skills/main/laws-of-ux/references/ux-laws-complete.md (MIT repo by a third party, "Source: lawsofux.com", 30 laws; definitions below may be copied or paraphrased from the site, cannot confirm). Its "When/Fix" notes are that author's code advice, not the site's takeaways, so omitted.

Definitions as quoted by that file:
1. Aesthetic-Usability Effect: users perceive aesthetically pleasing design as design that's more usable.
2. Law of Pragnanz: people perceive and interpret ambiguous or complex images as the simplest form possible.
3. Von Restorff Effect: the object that differs from the rest is most likely to be remembered.
4. Law of Similarity: the eye perceives similar elements as a complete picture, shape, or group.
5. Law of Proximity: objects that are near each other tend to be grouped together.
6. Law of Common Region: elements sharing an area with a clearly defined boundary are perceived as a group.
7. Law of Uniform Connectedness: visually connected elements are perceived as more related.
8. Cognitive Load: the mental resources needed to understand and interact with an interface.
9. Hick's Law: decision time increases with the number and complexity of choices.
10. Miller's Law: the average person can keep 7 (plus or minus 2) items in working memory.
11. Chunking: breaking information into pieces, then grouping them into meaningful wholes.
12. Choice Overload: people get overwhelmed when presented with a large number of options.
13. Cognitive Bias: systematic patterns of deviation from norm or rationality in judgment.
14. Fitts's Law: time to acquire a target depends on distance to and size of the target.
15. Doherty Threshold: productivity soars when computer and user interact at a pace (<400ms) so neither waits.
16. Flow: the mental state of being fully immersed in energized focus.
17. Goal-Gradient Effect: the tendency to approach a goal increases with proximity to it.
18. Serial Position Effect: users best remember the first and last items in a series.
19. Peak-End Rule: people judge an experience by its peak and its end, not the total.
20. Zeigarnik Effect: people remember uncompleted or interrupted tasks better than completed ones.
21. Working Memory: a cognitive system that temporarily holds and manipulates information for tasks.
22. Jakob's Law: users prefer your site to work the same way as the other sites they already know.
23. Postel's Law: be liberal in what you accept, and conservative in what you send.
24. Tesler's Law: any system has a certain amount of complexity which cannot be reduced.
25. Occam's Razor: among equally predictive hypotheses, choose the one with fewest assumptions.
26. Pareto Principle: roughly 80% of effects come from 20% of causes.
27. Selective Attention: directing awareness to relevant stimuli while ignoring irrelevant ones.
28. Mental Model: what the user believes about the system, based on past experience.
29. Paradox of the Active User: users never read manuals but start using the software immediately.
30. Parkinson's Law: any task will inflate until all the available time is spent.

Key takeaways per law from the site: not verified. Re-fetch from a host the proxy allows, or ask the owner to allowlist lawsofux.com.

## 6. What makes a frontend look AI-generated (and what Lectale does instead)

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
