# Home screen: build review

| | |
|---|---|
| **Build** | `claude/m2-preview` at `36b8d15`, `apps/flutter_client`, `flutter build web --release` |
| **Judged against** | `../screens/home.md`, `../inventory.md` (Keyboard: every screen; Breakpoints), `../token-plan.md`, `.claude/skills/screen-spec/references/ai-tells.md` |
| **Date** | 2026-11-21 |
| **Verdict** | **Fix required**: five open hard stops (H1 to H5) |
| **Screenshots** | `home-build/`, lossless WebP, captured at device scale 1 |

## How it was captured

- The build was served with `python3 -m http.server` and captured with Playwright Chromium at device scale 1, at 320, 360, 768 and 1440 px wide, in light and dark.
- The sandbox proxy refuses `www.gstatic.com`, so the CanvasKit requests were routed to the build's own `canvaskit/` folder. The rendering is otherwise unchanged.
- `/api/courses/import` was faked with Playwright routing. The 422 used three validator messages copied from `apps/edge_api/src/contract/` (`INVALID_REPO_PATH`, `INVALID_TIMESTAMP`, `SCHEMA_INVALID`).
- Semantics were enabled by clicking `flt-semantics-placeholder`. axe-core 4.10.2 was used with the tags `wcag2a`, `wcag2aa`, `wcag21a`, `wcag21aa`, `wcag22aa` and `best-practice`. The proxy refuses cdnjs and jsdelivr (403), so axe came from the npm registry (`npm pack axe-core@4.10.2`) and was injected with `page.addScriptTag({path})`.
- Contrast was computed with the WCAG 2 formula from the theme seeds and litse-ui's own blend rules (`alert.dart`, `input.dart`). It was then checked against sampled pixels, and the alert fill (#E5DAD3 light, #3E3633 dark) and the dark field fill (#353836) matched exactly.

## Fidelity ledger

Severity: **hard stop** blocks the merge; **major** must be fixed or answered with a reason; **minor** goes to the backlog.

| # | Severity | Point | Plan says | Image shows (file, region) | Reference | Fix |
|---|---|---|---|---|---|---|
| H1 | Hard stop (a11y MAJOR) | Address field focus | The gold ring outside a 2 dp Paper gap on every control; ring at least 3:1 | `zoom-field-focus-light.webp`, `tab-0-field-autofocus-1440-light.webp`: a 1 px gold border plus a 30% gold halo with no Paper gap. The halo is 1.50:1 on Paper (2.33:1 dark). Invalid and focused (`zoom-field-invalid-focus-light.webp`, `empty-submit-1440-light.webp`, `other-host-360-light.webp`): the border is red both at rest and with focus, so **the only sign of focus is a 30% red halo at 1.65:1** (1.84:1 dark), and it is not gold. The button ring is correct (`zoom-button-ring-light.webp`, `tab-1-open-course-1440-dark.webp`). | WCAG 2.4.7 Focus Visible; 1.4.11 Non-text Contrast (house rule 3:1); `inventory.md` Keyboard | litse-ui `lib/src/components/input.dart`: replace the `foregroundDecoration` halo (`accent.withValues(alpha: 0.3)`) with `DcFocusRing` in `colors.ring` (2 dp ring, 2 dp gap, outside). Keep `invalid` on the border only, so the ring stays gold when the field is invalid. |
| H2 | Hard stop (a11y CRITICAL) | Field name at wide widths | A labelled field (A11Y-003) | axe at 1440, light and dark: **`label` (critical) on `input#url`**. With semantics on, Tab from the skip link lands on `input#url` with no `aria-label`. At 360 (no autofocus) the same field is named "GitHub repository address…". The autofocus runs before semantics are enabled, and the engine's unnamed editing input stays in the tree. | WCAG 4.1.2 Name, Role, Value; 1.3.1; 3.3.2 | `home_screen.dart` `_AddressField(autofocus: isWideWindow(context))`: on web, don't use `autofocus`. Request focus after the first frame and again when semantics turn on (`SemanticsBinding.instance.addSemanticsEnabledListener`: unfocus, then `_field.requestFocus()`). Re-run axe until `#url` carries the name, then confirm with NVDA. |
| H3 | Hard stop (a11y MAJOR) | Enter drops focus | Loading: the field stays editable and Escape cancels (§6). Keyboard order (§8) | `loading-1440-light.webp`: after Enter the field loses its focus border and `document.activeElement` is `flutter-view`. `loading-escape-ignored-1440-light.webp`: Escape does nothing and "Reading the repository" stays. `loading-tab-restarts-1440-light.webp`: the next Tab goes to the skip link. `loading-escape-after-refocus-1440-light.webp`: once the field has focus again, Escape cancels, so focus loss is the cause. | WCAG 2.1.1 Keyboard, 2.4.3 Focus Order; home.md §6 | For `TextInputAction.go`, `EditableText`'s default `onEditingComplete` unfocuses. Pass `onEditingComplete: () {}` from `_AddressField`, and add the parameter to `DcInput` if it is missing. Also lift the Escape `CallbackShortcuts` above the `AppShell` focus scope so it works wherever focus is. |
| H4 | Hard stop | Skip link ring clipped | The skip link appears with the gold ring when focused | `zoom-skip-link-ring-light.webp`, `tab-2-skip-link-1440-light.webp`, `tab-1-skip-link-360-light.webp`: the link sits at y = 0. Its ring shows on three sides, and the top edge is cut off by the window (pixel row 0 is the card border, with no gold). | WCAG 2.4.7; 2.4.11 Focus Not Obscured | `app_shell.dart`: `PositionedDirectional(top: 0, …)` becomes `top: style.space(2)`, which leaves 9 dp for the 2 + 2 dp ring. |
| H5 | Hard stop | Edges on whole pixels; spacing scale | C3: edges snap to device pixels. Scale steps 1, 2, 3, 4, 6, 8, 12, 16 | `idle-768-light.webp`, `typed-360-light.webp`, field top and bottom edges: the 1 px border is split across two rows (#D5D4D0 / #969995). Its darkest row is **2.56:1** on Paper, while the side edges are #767B77 at 3.83:1. The cause is fractional y offsets from `space(1.5)` (6.75 dp, label to field and field to hint, not on the scale) and the 21.5 dp line heights above it. | `token-plan.md` Spacing (C3); WCAG 1.4.11 | `home_screen.dart`: change both `space(1.5)` gaps to `space(2)`, and round the column's top offsets to whole pixels. Better still, snap the decoration rect in litse-ui `DcInput` (C3 applies everywhere). |
| M1 | Major | Error alert hierarchy and colour | Signal red is for errors, "with an icon and a title". The problem row is the message, then the location, then the pointer and code (§9) | `invalid-manifest-1440-light.webp`, `invalid-manifest-1440-dark.webp`: **every line is red**: body, the three messages, locations, pointers, codes and the reference. Contrast passes (#7D282B on #E5DAD3 **6.89:1**; dark #EFADA6 on #3E3633 **6.29:1**), so the owner's contrast concern is **dismissed**. The real problem is the wall of red: it is hard to scan, and the 14 dp Mono pointer is the heaviest line in each row, outweighing the message it belongs to. | home.md §5, §9; token plan Colour rules | `failure_view.dart`: set the description `DefaultTextStyle` to `colors.foreground`, and make location and code `small` in `mutedForeground`. Use a smaller pointer (`code` at the `small` size). Keep red for the icon, the title and the border only. |
| M2 | Major | Reference breaks mid-ID | The support reference can be quoted (ERR-010) | `invalid-manifest-360-light.webp`, `not-found-360-dark.webp`: "…1c5f7e2b9d4" with a single "0" on the next line. `invalid-manifest-320-light.webp`: "…4d0e-9a / 62-…". | home.md §5 (Reference) | `failure_view.dart` `_Reference`: show "Reference" and the ID as two lines, with the ID in Mono at the `small` size (36 characters fit 255 dp at 320 px). Or insert U+200B after each hyphen, so breaks fall only at hyphens. |
| M3 | Major | Layout shift on submit | Motion: nothing moves except the spinner (§8) | `typed-1440-light.webp` against `loading-1440-light.webp`: the spinner widens the button, so the field's right edge moves from 466 to 443 px (23 px). It moves back when the answer arrives. The same happens at 768. | home.md §8 Motion | `home_screen.dart`: give `DcButton` a fixed minimum width equal to its loading width, or always reserve the 16 dp leading slot (an empty `SizedBox` when idle). |
| M4 | Major | Help line semantics | One h1, then the help line in reading order (§8) | Semantics dump at 1440: the help line becomes the **name of a `group`** wrapping the whole form (`role=group label="Any public GitHub…"`), so it is read before the h1. The 422 alert merges its title, body and reference into one group name in the same way. | WCAG 1.3.1, 1.3.2 Meaningful Sequence | `home_screen.dart`: wrap the help `Text` in `Semantics(container: true)`. In `failure_view.dart`, give the title, body and reference their own container nodes. |
| M5 | Major | Rate-limit text goes stale | The wait is spoken at its start and end. The button is disabled until the end (J5) | `rate-limited-768-light.webp`: correct (the button is disabled, `aria-disabled=true`, and Enter is ignored). `rate-limit-ended-1440-light.webp`: the button is enabled again, but the alert still says "Try again in 5 seconds." | journeys J5 rules | `home_screen.dart` / `home_copy.dart`: when `waitOver`, replace the alert body with `HomeCopy.waitOver`, or remove the alert. |
| m1 | Minor | Wordmark case | Logo brief: "lowercase wordmark", and the round-2 sheets set "lectale". home.md §5 and inventory: "Lectale" | `zoom-brand-light.webp`: **confirmed**: capital-L "Lectale" in Plex Sans Medium. The build follows home.md, so this is a conflict between specs, not a build bug. | `token-plan.md` Logo brief; home.md §5 | Owner decides. If lowercase: `AppCopy.wordmark = 'lectale'` with `Semantics(label: 'Lectale')`. |
| m2 | Minor | Mark on the start line | C8: brand mark and column share the start line | `zoom-brand-light.webp`: the painted mark starts at x≈39.5, not 36, because the path begins at 8/64 of its box (Codex). | inventory Breakpoints, C8 | `lectale_mark.dart`: offset the path by −8/64 × size, or trim the drawing box to x 8 to 56. |
| m3 | Minor | Gold behind text | "Gold … never a background behind text other than the button label" | `invalid-manifest-1440-light.webp`, field: the selected address sits on tan #D8C8AE, which is derived from the ring. Graphite on it is 9.19:1, so the text reads fine (Codex). | token plan Colour rules | `theme.dart`: set the selection colour to Sand, or to mulberry at low alpha. |
| m4 | Minor | Dark-theme field fill | Paper and Sand surfaces only | `idle-1440-dark.webp`, `idle-360-dark.webp`: the field is a #353836 block. In light it is Paper (`idle-1440-light.webp`). | token plan Colour | `_AddressField`: `DcInputStyle(backgroundColor: colors.canvas)`. The dark border is 4.01:1 on Paper, so contrast still holds. |
| m5 | Minor | Skip link hidden from the tree | A skip link for keyboard and screen-reader users (A11Y-001) | Semantics dump: the skip link has no node until it has focus, because it is translated −400 px off screen. Tab reaches it (`tab-1-skip-link-360-light.webp`), but a browse-mode links list does not. Activating it moves focus to main, and the next Tab reaches the field (checked). | WCAG 2.4.1 | `skip_link.dart`: replace the translate with `Opacity(opacity: focused ? 1 : 0, alwaysIncludeSemantics: true)` plus `IgnorePointer(ignoring: !focused)`. |
| m6 | Minor | Banner landmark | §8: banner (top bar), main | axe `region` (moderate): the wordmark is outside any landmark. Flutter's `SemanticsRole` has `main`, `navigation`, `region`, `complementary` and `contentInfo`, but **no banner**. | home.md §8 | Record an erratum: banner can't be expressed. Either accept the axe finding, or use `SemanticsRole.region` with a label. |
| m7 | Minor | 1440 emptiness | §7 Desktop: "column 560 dp on the start line … the rest stays empty" | `idle-1440-light.webp`: the content fills about the top-left 600 × 390 px. One start line (x = 36) runs through the mark, h1, field, hint and alert, so the emptiness **reads as intentional, not broken** (Codex agrees). It does read as sparse at idle, with nothing closing the page. | home.md §7; Q1 | Don't centre the column or fill the space. The footer from Q1 (accessibility statement, privacy; WCAG 3.2.6) would close the page. |
| m8 | Owner question | Memorable element on Home | Pre-ship check 2: name the Lectale-specific element | `idle-1440-light.webp`: mulberry appears only in the 28 dp mark. The gold button is the strongest colour, and the ribbon has no place on Home. The screen could belong to any form app. | `ai-tells.md` check 2 | Within the owner's palette and face: set the Home h1 in the page-title voice (Source Serif 4 semibold, mulberry), as course and lesson titles are. This changes the plan, so the owner decides. |

### Checked and matching the plan

- **No overflow:** `scrollWidth` equals the viewport at 320, 360, 768 and 1440 in every state. Text only wraps; nothing clips.
- **Layout:** the column is 560 dp on the 36 dp start line (18 dp under 600). The top gap is 72 / 54 / 36 dp at 1440 / 768 / 360 (§7). The button goes full width under 600.
- **Type:** the h1 is `display` 30/36 Plex semibold (semantics box 37 px). Help is `body` 14, the hint `small`, the wordmark `title` medium.
- **Targets:** field and button are 52 dp, the skip link 44 dp, and the 360 button is 324 × 52.
- **Contrast:** heading 13.40 / 13.79; help and hint 5.79 / 7.60; button label 5.54 / 11.27; field rest border 3.83 / 4.01; inline error 6.40 / 7.80; alert icon 5.24 / 5.31 (light / dark, all :1).
- **Copy and live regions:** copy matches §6 and §9. The live region says "Reading the repository", "Still reading. Large courses take longer." (`loading-slow-1440-light.webp`), "course.yaml can't be used. 2 problems.", "Repository not available", "Too many requests. Try again in 4 seconds." and, at the end of the wait, "You can try again."
- **Tab order:** at 1440 the field is autofocused (the spec's exception), then Open course, then the skip link, then the field. At 360 it is the skip link, the field, then Open course. The ring is gold with a Paper gap on the button (`tab-1-open-course-1440-light.webp`) and the skip link.

## axe-core result

| Run | Violations |
|---|---|
| 1440 light idle, 1440 dark idle, 1440 light 422 | `label` (critical) on `#url` (H2); `region` (moderate) on `#url` and on the wordmark node (m6) |
| 360 light idle, 360 light 422 | `region` (moderate) on the wordmark node only |
| All runs | `color-contrast` incomplete: axe can't see canvas text, so contrast was measured by hand (above) |

A clean axe run isn't a pass on a canvas app. axe sees only the semantics tree.

## Codex second opinion

The images sent were `idle-1440-light`, `idle-360-light`, `idle-1440-dark` and `invalid-manifest-1440-light` (`codex exec --sandbox read-only`, codex-cli logged in). What it found, and what I did with each point:

| Codex point | Codex severity | Disposition |
|---|---|---|
| The field focus halo has no Paper gap; 1.5:1 light, 2.4:1 dark | Major | Adopted and raised to a hard stop (H1). The invalid state makes it a real focus-visibility failure. |
| The selection behind the address is tan, derived from gold | Minor | Adopted (m3) |
| Alert title close to body size; problem rows run into their technical lines | Minor | Merged into M1 |
| The dark field fill is a conspicuous charcoal block | Minor | Adopted (m4) |
| The field's top edge is softer than its sides (split across two pixel rows) | Minor | Verified by pixels at 2.56:1 and raised to a hard stop (H5) |
| The mark starts about 3 px right of the start line | Minor | Verified (x≈39.5); m2 |
| No clipping at 360; 1440 emptiness reads as intentional; no generic tells | None | Agreed on clipping and on emptiness. On the tells, I disagree in part (m8: no Lectale-specific element on Home). |

## Not checked

- Text scale at 200 and 400 percent, the high-contrast schemes, reduced motion and Windows forced colours.
- Hover states.
- The offline, timeout, 502/503, `manifest_missing`, 413 and other-error states, and the success navigation to Course.
- Native layouts (no goldens were run) and real screen readers (NVDA, VoiceOver, TalkBack, Orca). H2 and m5 need an NVDA check after the fix.
