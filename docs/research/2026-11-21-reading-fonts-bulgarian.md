# Reading typeface with Bulgarian letterforms, build vs buy (2026-11-21)

Need: a serif for the reading area (18 dp text, 30 dp line height, course and lesson titles) whose Bulgarian Cyrillic looks right.   Requirement IDs: none; serves the open "reading face" row in `docs/ux/token-plan.md`, Type.
Constraints checked: licence MIT-compatible (SIL OFL) / six platforms (not verified, see end) / litse-ui (fonts are data, not widgets) / cost (free) / Workers (not affected: fonts ship in the Flutter bundle)

Everything below was fetched or measured on 2026-11-21. Font files were downloaded into the session scratchpad, never into the repo, and read with fontTools and Pillow (raqm). Specimen: `docs/research/reading-fonts-bulgarian.webp`, made by `docs/research/reading-fonts-bulgarian.py`.

## Findings

1. **Literata does not have Bulgarian forms, in the upstream files either.** The upstream variable roman file is byte-identical to the Google Fonts one (`cmp`). Its `cyrl` script has no language systems, and rendering `language='bg'` and `language='ru'` gives identical pixels for all 13 test letters.
2. **Three faces pass every requirement:** Source Serif 4, Piazzolla, Vollkorn. Literata fails only on Bulgarian forms. No tested face has Bulgarian forms by default: in every font, `bg` and `ru` renders differ only where a BGR lookup exists.
3. **Flutter applies `locl` when `TextStyle.locale` is `bg`.** The locale reaches HarfBuzz as the buffer language (chain below). Plain `Text` inherits the app locale, so the reader must set `locale` from `course.language` (required in the course schema) or Bulgarian courses in an English UI show the Russian-style forms.
4. **The Bulgarian upright forms are strongly cursive-looking** (д, л, в, г, п, т, ю). All four faces with a BGR lookup do this, so it is the shared convention, but the owner has to judge whether it looks right to a Bulgarian eye. Look at the specimen first.

## Shortlist, side by side

| | Source Serif 4 | Piazzolla | Vollkorn | Literata (control) |
|---|---|---|---|---|
| Licence | SIL OFL 1.1; name table: "with Reserved Font Name 'Source'" | SIL OFL 1.1 | SIL OFL 1.1 | SIL OFL 1.1 |
| Version fetched | 4.005 (upstream release) | 2.005 (Google Fonts build) | 5.000 (upstream, same size as Google Fonts) | 3.103 (upstream) |
| Latin, Greek, Cyrillic | all three; no test letter missing | all three | all three | all three |
| Full Bulgarian alphabet а-я, А-Я, ѝ Ѝ | present | present | present | present |
| Greek μ σ π Ω Δ θ λ | present | present | present | present |
| BGR `locl` (Cyrillic, language system `BGR `) | **yes**, roman and italic. Rendered bg differs from ru for roman `длжквгптфюЛФ`, italic `длжквфюЛФ` | **yes**, roman and italic. Roman `длжквгптюДЛ`, italic `длжквюДЛ` | **yes**, roman and italic. Roman `длжквгптюДЛФ`, italic `джквюДЛФ` | **no.** Cyrillic script has no language systems; bg and ru identical |
| Variable axes (min, default, max) | wght 200, 400, 900; opsz 8, 20, 60 | wght 100, **100**, 900; opsz 8, 30, 30 | wght 400, 400, 900 | wght 200, 400, 900; opsz 7, 12, 72 |
| Italic | yes, variable file | yes, variable file | yes, variable file | yes, variable file |
| Roman + italic, bytes | 1,204,208 + 850,036 = 2,054,244 | 624,956 + 618,116 = 1,243,072 | 577,864 + 441,264 = 1,019,128 | 955,132 + 902,728 = 1,857,860 |
| Same, brotli q9 (web delivery estimate) | 891,224 | 575,058 | 434,251 | 906,494 |
| Same, subset to Latin, Greek, Cyrillic (indicative) | 1,608,244 | 693,404 | 560,852 | 1,190,044 |
| Avg width, English prose (em per character, wght 400, opsz 18) | 0.438 | 0.415 | 0.416 | 0.452 |
| Characters per 32 em line, from that width | about 73 | about 77 | about 77 | about 71 |
| Designer (Google Fonts metadata) | Frank Grießhammer | Juan Pablo del Peral, HT Fonts | Friedrich Althausen | Type Together (README) |

How the numbers were made:

- BGR evidence: fontTools reads `GSUB` ScriptList for `cyrl`, language system `BGR `, feature `locl`, and the lookup indices. Then Pillow (raqm, HarfBuzz) renders `длжквгптфюДЛФ` with `language='bg'` and `language='ru'` and compares pixels. Only letters that differ are listed.
- Width: the specimen's English paragraph (`EN` in the script), advance sum divided by character count, at 1000 px. Run `python3 -I reading-fonts-bulgarian.py FONT_DIR --widths`. The Literata figure (0.452) differs from the design review's 0.461 because text and opsz differ; compare faces only within this table.
- Subset: `fontTools.subset` with U+0020-017F, punctuation, U+0370-03FF, U+0400-045F, all layout features kept. I did not re-check that BGR survives the subset. Subsetting a face with a Reserved Font Name may require renaming it under the OFL; I did not verify that reading.

### Source Serif 4

- Sources (fetched 2026-11-21): `raw.githubusercontent.com/adobe-fonts/source-serif/release/VAR/SourceSerif4Variable-Roman.ttf` and `-Italic.ttf`; `.../main/LICENSE.md` ("with Reserved Font Name ‘Source’"); `.../main/README.md`; `raw.githubusercontent.com/google/fonts/main/ofl/sourceserif4/METADATA.pb`.
- Good: neutral, quiet in the specimen; opsz axis down to 8 and up to 60 lets titles and text differ; BGR in both styles; width 0.438 em gives the most air per line.
- Cost: the largest of the three at 2.05 MB (0.89 MB brotli). The Google Fonts build is a different file (1,209,508 bytes roman) from the upstream one (1,204,208); I measured upstream.

### Piazzolla

- Sources: `raw.githubusercontent.com/google/fonts/main/ofl/piazzolla/Piazzolla%5Bopsz%2Cwght%5D.ttf` and `-Italic`; `.../OFL.txt`; `.../METADATA.pb`; upstream `raw.githubusercontent.com/huertatipografica/piazzolla/master/README.md` (no font files at the paths I tried: 404).
- Good: 1.24 MB for both styles; BGR in both styles; narrow, so a line holds about 77 characters.
- Watch: the default weight is 100, so every style must pass `wght` explicitly or it renders Thin. The opsz axis stops at 30, so large titles do not get a different design.
- Upstream README text: "compact appearance which allows for small font sizes and tight leading". That is a vendor claim, not measured. Judge the look from the specimen.

### Vollkorn

- Sources: `raw.githubusercontent.com/FAlthausen/Vollkorn-Typeface/master/fonts/variable/Vollkorn%5Bwght%5D.ttf` and `-Italic`; `.../master/README.md` ("Published under the SIL OFL license"); `google/fonts` OFL.txt and METADATA.pb.
- Good: smallest bundle (1.02 MB, 0.43 MB brotli); wght 400 to 900 supports the dark-mode offset and semibold; BGR in both styles.
- Watch: no opsz axis. Italic BGR leaves `л` unchanged in the render test, unlike the other two. In the specimen it reads darker and more rustic than the other two. That is my visual judgement, not a measurement.

### Literata (control, rejected on Bulgarian forms)

- Sources: `raw.githubusercontent.com/googlefonts/literata/main/fonts/variable/Literata%5Bopsz%2Cwght%5D.ttf` and `Literata-Italic%5Bopsz%2Cwght%5D.ttf`; `.../main/README.md` ("supports Greek, Cyrillic, PinYin, and Vietnamese", "published with an OpenFont License (OFL)"; no mention of Bulgarian); `.../main/OFL.txt`; `raw.githubusercontent.com/google/fonts/main/ofl/literata/Literata%5Bopsz%2Cwght%5D.ttf` (identical to upstream).
- Cyrillic and Greek are complete and the face is quiet. If the owner decides Bulgarian forms are optional, Literata remains a fit; it would then show the Russian-style forms for Bulgarian text.

## Also tested and rejected

All fetched from `raw.githubusercontent.com/google/fonts/main/ofl/<family>/` unless noted. Same fontTools and Pillow method.

| Face (version) | Fails on | Detail |
|---|---|---|
| Alegreya 2.009, variable | BGR | `cyrl` language systems `BSH`, `CHU`, `SRB` (roman); bg and ru render identically. 851 KB for both styles. Width 0.390 |
| Gentium Book Plus 6.101, static | BGR | `cyrl` has `MKD`, `SRB` only. Feature `cv84` and `locl` touch only `г д п т`; I did not test them as Bulgarian forms. Static files only (regular and italic measured: 1.70 MB). Width 0.404 |
| Noto Serif 2.015 and 2.013, variable | BGR, size | `cyrl` has `MKD`, `SRB`; identical bg and ru render. 4.3 MB for both styles. Width 0.460 |
| PT Serif Web 1.000W, static | BGR, coverage | `cyrl` has `BSH`, `CHU`. Missing ѝ Ѝ and Greek σ θ λ. Width 0.429 |
| Lora 3.008, variable | Greek | BGR works, but σ θ λ are missing. 433 KB. Width 0.449 |
| Merriweather 2.100, variable | Greek, size | BGR works, but σ θ are missing. 9.2 MB. Width 0.461 |
| Spectral 2.005, static | Coverage | BGR works, but ѝ Ѝ and σ Ω θ λ are missing |
| Roboto Serif 1.008, variable | Greek, italic, size | σ θ λ missing; BGR only in roman, none in italic. 8.6 MB |
| Brygada 1918 3.006, variable | BGR | Cyrillic and Greek complete, no BGR. 486 KB |
| EB Garamond 1.003, Charis SIL 6.101 | BGR | Cyrillic complete; `cyrl` has `MKD`, `SRB` only |
| Newsreader, Crimson Pro, Faustina, Petrona, Andada Pro | Cyrillic | The Cyrillic letters are absent from the files I tested |

A serif designed in Bulgaria: **not found.** GitHub repository search for the terms "bulgarian serif typeface" returned nothing, and the Google Fonts catalogue listing could not be fetched (see blocked hosts). Not verified either way.

## Does Flutter apply `locl` for `locale: Locale('bg')`?

Yes, by this chain. Quotes are from files fetched 2026-11-21. I fetched Flutter `master` and Skia `main`, not the revisions pinned by Flutter 3.50.1.

1. `TextStyle.locale` is documented as "The locale used to select region-specific glyphs." (`raw.githubusercontent.com/flutter/flutter/master/packages/flutter/lib/src/painting/text_style.dart`).
2. Engine, native: `text_style.setLocale(SkString(txt.locale.c_str()));` (`.../engine/src/flutter/txt/src/skia/paragraph_builder_skia.cc`, line 107).
3. Engine, web: CanvasKit `properties.locale = locale.toLanguageTag();` (`.../lib/web_ui/lib/src/engine/canvaskit/text.dart`, line 180). Skwasm calls `textStyleSetLocale(handle, localeHandle)` with `style.locale!.toLanguageTag()` (`.../skwasm/skwasm_impl/paragraph.dart`, lines 304-306).
4. Skia paragraph: `LangIterator` takes `fCurrentLocale(defaultStyle.getLocale())` and returns `fCurrentLocale.c_str()` from `currentLanguage()` (`raw.githubusercontent.com/google/skia/main/modules/skparagraph/src/Iterators.h`). `OneLineShaper.cpp` passes it to `shaper->shape(... langIter ...)`.
5. HarfBuzz shaper: `hb_buffer_set_language(buffer, hbLanguage);` with `hbLanguage = hb_language_from_string(language.currentLanguage(), -1)` (`.../modules/skshaper/src/SkShaper_harfbuzz.cpp`, lines 1472-1476).

So `locl` under language system `BGR ` is applied when the run's locale is `bg`, and a font with Bulgarian forms only in `locl` is enough. A font with Bulgarian forms by default is not needed. Pillow with raqm drives the same shaper library, and `language='bg'` applied the lookups in the specimen. Flutter itself was not run.

What follows for the code:

- Set `TextStyle(locale: Locale(course.language))` on reading text and titles. `course.language` is required and matches `^[a-z]{2,3}(?:-[A-Z]{2})?$` (`spec/v4.0/schemas/course-v3.schema.json`, lines 32-35 and 113-118). A resource can carry its own optional `language` (line 354).
- Flutter's `TextStyle` source I read has `fontVariations` (example `FontVariation('wght', 900.0)`) and no mention of automatic optical size. Whether Flutter sets `opsz` from the font size: not verified. Plan to pass `FontVariation('opsz', ...)` explicitly for Source Serif 4 and Piazzolla.

## Recommendation

Needs owner decision. Open the specimen and pick by eye; the Bulgarian reader's judgement decides.

1. **Source Serif 4** is my first choice: the full set of requirements, `opsz` and `wght` axes, BGR in both styles, the quietest look in the specimen. It costs 2.05 MB uncompressed.
2. **Piazzolla**: 40 percent smaller and denser (about 77 characters per 32 em). Every style must set `wght`.
3. **Vollkorn**: the smallest. No `opsz`, italic leaves `л` unchanged, and it looks the heaviest here.

Not recommended: Literata (no BGR), and every face in the rejected table.

Adopting any of them adds a font dependency. AGENTS.md section 5 says to ask the owner first; this note is the research record for that ask. If the owner picks one, an ADR should record the face, the `locale` rule and the subsetting decision.

## Not verified

- Flutter rendering on the six platforms, and variable-font support (`wght`, `opsz`) on each. Not run.
- Flutter's pinned Skia and engine revisions; I read `master` and `main`.
- HarfBuzz's mapping of `bg` to the `BGR ` tag: shown by rendering, not by reading HarfBuzz source.
- Upstream sources for Piazzolla and Alegreya (raw paths 404, GitHub API refused): the Google Fonts mirror was used. Upstream for Noto Serif, PT Serif, Gentium: not fetched; the GitHub README at `silnrsi/font-gentium` returned 404.
- A Bulgarian-designed serif: not found.
- Whether subsetting a font with a Reserved Font Name needs renaming, and whether the BGR lookup survives my subset.
- The Bulgarian paragraph in the specimen was written by the researcher, not proofread by a native reader.
- Blocked or failed hosts: `api.github.com` repo and tree endpoints (403, "access not enabled for this session"), `fonts.google.com/metadata/fonts` (connection failed), `www.googleapis.com/webfonts` (403), `github.com/google/fonts/tree/main/ofl` (403), `html.duckduckgo.com` (connection failed).

Sources (all fetched 2026-11-21): `raw.githubusercontent.com` paths named above for `googlefonts/literata`, `adobe-fonts/source-serif`, `huertatipografica/Alegreya`, `huertatipografica/piazzolla`, `FAlthausen/Vollkorn-Typeface`, `google/fonts` (`ofl/*`), `flutter/flutter`, `google/skia`; `registry.npmjs.org` search (no relevant Bulgarian serif); local `spec/v4.0/schemas/course-v3.schema.json`.
