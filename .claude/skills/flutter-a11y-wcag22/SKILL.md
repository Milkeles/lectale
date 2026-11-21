---
name: flutter-a11y-wcag22
description: WCAG 2.2 AA checklist and verification recipes for Lectale's Flutter app on web, Android, iOS, Linux, Windows and macOS. Use when building, reviewing or testing any screen or widget for accessibility, semantics labels, keyboard and focus, target size, text scaling, reflow, reduced motion, authentication forms, drag interactions, or when triaging an a11y finding as CRITICAL, MAJOR or MINOR.
---

# WCAG 2.2 AA for Lectale (Flutter, six platforms)

The spec's target is WCAG 2.2 Level AA (A11Y-001 to A11Y-007 in `spec/v4.0/docs/WCAG_ACCESSIBILITY.md`). Automated checks catch only part of it, so every item below has an automated check where one exists and a manual pass where it does not. Test snippets are in [references/verification.md](references/verification.md).

Structure and severity triage follow the Very Good Ventures accessibility skill (MIT, github.com/VeryGoodOpenSource/vgv-ai-flutter-plugin) as inspiration; its Material-specific advice is left out.

## What devchat_ui already does

Color themes are built by measured contrast: text 4.5:1 (1.4.3), 7:1 in high contrast, 3:1 for the focus ring and control borders (1.4.11). Controls draw a visible `DcFocusRing`, keep targets at least 24 x 24 px, set semantics roles, and stop animating when `MediaQuery.disableAnimations` is true. So: use `Dc*` components and theme roles, and contrast is not re-checked by hand. Custom controls must be built on `DcPressable` and `DcFocusRing`. Contrast problems come from hardcoded colors, text on images, or a `DcColorTheme` with `colors.copyWith(...)` overrides, so check those.

## Checklist

| Criterion | Rule in Flutter | How it is verified |
| --- | --- | --- |
| 1.1.1 Non-text Content | Informative images get `semanticLabel` or `Semantics(label:)`; decorative ones `excludeFromSemantics: true`. Icon-only buttons use `DcButton.icon(semanticLabel:)` | `labeledTapTargetGuideline`; semantics tree |
| 1.3.1 Info and Relationships, 4.1.2 Name, Role, Value | One node per control with label, role and state. Use `Semantics(header: true)` for headings, `MergeSemantics` only around static label/value pairs. Never `ExcludeSemantics` on anything interactive, because it removes the control from screen readers | `isSemantics(...)` test; semantics debugger |
| 1.3.5 Identify Input Purpose | `autofillHints` on every `DcInput` that collects personal data | widget test on the property |
| 1.4.1 Use of Color | Pair color with text or an icon (errors, status, selection) | review; grayscale screenshot |
| 1.4.3 Contrast, 1.4.11 Non-text Contrast | Theme roles only; no hardcoded colors | `textContrastGuideline`; `DcContrast.ratio` for custom pairs |
| 1.4.4 Resize Text | Works at 200% text scale: no fixed-height boxes around `Text`; use min-height constraints | widget test with `textScaler`; goldens |
| 1.4.10 Reflow | No horizontal scroll at 320 CSS px wide, except inherently two-dimensional content (PDF page, notebook output, code) | Playwright at 320 px; widget test at `Size(320, 640)` |
| 1.4.12 Text Spacing | Text containers tolerate larger line, word and letter spacing | Playwright style override; manual |
| 1.4.13 Content on Hover or Focus | `DcTooltip` content is dismissible (Escape), hoverable and persistent | tooltip test; manual |
| 2.1.1 Keyboard, 2.1.2 No Keyboard Trap | Everything works by keyboard; dialogs close with Escape and return focus. Never a bare `GestureDetector` for actions | keyboard traversal test; manual |
| 2.4.1 Bypass Blocks | A skip link and labeled landmarks (A11Y-001); skip link is a missing litse-ui component | Playwright Tab test; manual |
| 2.4.3 Focus Order | Order follows reading order; use `FocusTraversalGroup` and `OrderedTraversalPolicy` only when needed | Tab-order test |
| 2.4.7 Focus Visible | Ring shows after keyboard navigation on every focusable element | `DcFocusRing` test; screenshot with Tab |
| 2.4.11 Focus Not Obscured (Minimum) | A focused item is never fully hidden by a sticky header, toast, sheet or the on-screen keyboard; call `Scrollable.ensureVisible` on focus | scroll-and-Tab test; Playwright bounding box check |
| 2.5.1 Pointer Gestures | Any multi-point or path gesture has a single-pointer alternative | review |
| 2.5.7 Dragging Movements | Every drag has a click or key alternative on the same screen: buttons for reorder, steppers beside sliders, a Browse button beside a drop zone | review; keyboard test |
| 2.5.8 Target Size (Minimum) | At least 24 x 24 px for pointer targets; use 44 px or more in the `comfortable` style on touch | `wcagTargetSizeGuideline`; `androidTapTargetGuideline`, `iOSTapTargetGuideline` |
| 3.2.6 Consistent Help | Help, contact and the accessibility statement link sit in the same place on every screen (shared footer or menu) | review across screens |
| 3.3.1 Error Identification, 3.3.2 Labels or Instructions | Error text names the field and the fix; `invalid` plus a message, not color alone; label every input | widget test; see `ui-copy` |
| 3.3.7 Redundant Entry | Do not ask again for what the person already entered in the same flow; keep it in Riverpod state or prefill | flow review |
| 3.3.8 Accessible Authentication (Minimum) | No cognitive test to sign in: allow paste and password managers (`autofillHints`, no blocked paste), offer a passwordless or provider option; no CAPTCHA that needs puzzle solving or transcription | review; manual with a password manager |
| 4.1.3 Status Messages | Async results announce themselves: `DcAlert(announce: true)` or `SemanticsService.announce` | semantics test; screen reader |
| 2.2.2 Pause, Stop, Hide; 2.3.3 Animation from Interactions (AAA, kept as a house rule) | Respect `disableAnimations`; no autoplay with sound; moving content longer than 5 s can be paused | reduced-motion test; manual |

Focus Appearance (2.4.13) is AAA in WCAG 2.2; devchat_ui meets its 3:1 ring contrast anyway.

## Severity triage

Report each finding with the criterion number and name (never a bare "2.5.8"), a severity, and a fix as a code change.

- **CRITICAL**: a task cannot be completed with a keyboard or screen reader (unlabeled primary control, keyboard trap, content hidden from semantics, focus fully obscured).
- **MAJOR**: the task is possible but hard (missing 24 px target, no visible focus on one control, contrast below 4.5:1, clipped text at 200%, drag-only action with no alternative).
- **MINOR**: friction without blocking (redundant label wording, heading level skipped, hint text missing).

CRITICAL and MAJOR block the merge; MINOR goes to the backlog (A11Y-T04).

## Platform notes

- **Web**: Flutter's semantics tree is off until the invisible "Enable accessibility" button is activated, or `SemanticsBinding.instance.ensureSemantics()` runs. Playwright and axe-core must switch it on first (see the reference).
- **Android / iOS**: TalkBack and VoiceOver read the semantics tree; test text scaling at the largest system size.
- **Windows / macOS / Linux**: NVDA or Narrator, VoiceOver, and Orca read the native accessibility bridge. Record exactly what was tested on each, because coverage differs by platform.

## Manual pass (before each release)

Automated checks cover only part of WCAG. Before each release, run the critical tasks from A11Y-T01 (find a course, open a README, read a PDF, open a notebook, play video with the consent gate) with NVDA on Windows, VoiceOver on macOS and iOS, and TalkBack on Android. Note the date, version, tools and defects in the accessibility statement's test log.
