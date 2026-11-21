# Third-party skills

Five skills in this directory are copied from other projects. Each keeps its upstream `SKILL.md` text unchanged and its upstream license file as `LICENSE.txt` in its own folder. Lectale adds one blockquote ("Lectale adaptation") directly after the frontmatter, and nothing else. Fetched on 2026-11-21.

| Skill | Upstream | Commit | License | What Lectale added |
| --- | --- | --- | --- | --- |
| `frontend-design` | https://github.com/anthropics/skills/tree/main/skills/frontend-design | `e4bb5d960d87126ff3b3a8af1a104b7db67560ba` | Apache-2.0 (the skill's own `LICENSE.txt`; the repository has no root LICENSE, and its README says most skills are Apache 2.0) | Adaptation block: read the CSS and page wording as Flutter widgets, express palette and type through `DcColorTheme` and `DcStyle`, no Material, Riverpod |
| `flutter-build-responsive-layout` | https://github.com/flutter/agent-plugins/tree/main/skills/flutter-build-responsive-layout | `ff6d472ee66dbed566c4500edee460c94fde0a02` | BSD-3-Clause, Copyright 2026 The Flutter Authors | Adaptation block: devchat_ui instead of Material in examples, Riverpod, check at 360, 768 and 1440 px and 320 px reflow |
| `flutter-fix-layout-issues` | https://github.com/flutter/agent-plugins/tree/main/skills/flutter-fix-layout-issues | `ff6d472ee66dbed566c4500edee460c94fde0a02` | BSD-3-Clause | Adaptation block: devchat_ui instead of Material, fall back to test output when the Flutter MCP tools are absent |
| `flutter-add-widget-test` | https://github.com/flutter/agent-plugins/tree/main/skills/flutter-add-widget-test | `ff6d472ee66dbed566c4500edee460c94fde0a02` | BSD-3-Clause | Adaptation block: harness wraps with `DcTheme` over `WidgetsApp` (`pumpDc`, `pumpScreen`), never `MaterialApp` |
| `flutter-add-integration-test` | https://github.com/flutter/agent-plugins/tree/main/skills/flutter-add-integration-test | `ff6d472ee66dbed566c4500edee460c94fde0a02` | BSD-3-Clause | Adaptation block: run the app as `main()` does, with `DcTheme` and `ProviderScope`, no `MaterialApp` |

Both licenses allow redistribution with modification. BSD-3-Clause requires keeping the copyright notice and disclaimer (kept in each `LICENSE.txt`) and forbids using the Flutter Authors' names to endorse a derived product. Apache-2.0 requires the license text and a statement of changes, which the adaptation block provides.

## Inspiration only (nothing copied)

- **Very Good Ventures accessibility skill**, https://github.com/VeryGoodOpenSource/vgv-ai-flutter-plugin, commit `316390b5d95f54e692db76f2b73140324ecd79d7`, MIT, Copyright (c) 2026 Very Good Ventures. The checklist-plus-severity structure and the finding format of `flutter-a11y-wcag22` follow it; Material-specific advice was dropped and the text is Lectale's own.
- **OpenAI `frontend-app-builder` skill**, https://github.com/openai/plugins (`plugins/build-web-apps/skills/frontend-app-builder`), commit `981b02c0c44058b595f3b4180002c3ae3c806d40`. No license file was found at the repository root or in the plugin folder, so no text was copied. The idea of a fidelity ledger with at least five comparison points and a list of hard stops in `visual-review-loop` is restated in Lectale's own words.
- **WCAG 2.2** criterion numbers and names in `flutter-a11y-wcag22` were checked against https://www.w3.org/TR/WCAG22/.

## Local skills (Lectale, MIT with the repository)

`devchat-ui-usage`, `flutter-a11y-wcag22`, `visual-review-loop`, `ui-copy`.
