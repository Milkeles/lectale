# Requests for litse-ui

Things the app works around because litse-ui is not ours to change. One line per item: the component, the problem, the suggested change and the review row. Remove a line when litse-ui ships the change and the workaround is deleted.

| Component | Problem | Suggested change | Review row |
|---|---|---|---|
| `DcInput` (`lib/src/components/input.dart`) | A focused field draws a border in the ring color plus a 30 percent halo just outside it, with no gap. The halo is 1.5:1 on Paper (2.3:1 dark), and an invalid field gets a red halo, so focus on an invalid field is never gold and never reaches 3:1. | Replace the `foregroundDecoration` halo with `DcFocusRing` (ring color, the style's width and gap, outside the field) and keep `invalid` on the border only. Not worked around yet: the interrupted work's `RingedField` (clip the halo off, draw the ring outside) still showed the halo in a pixel test, so it was not reused. | H1 |
| `DcInput` | No `onEditingComplete`. Without it `EditableText` drops focus after Enter for `TextInputAction.go`, so Escape and Tab stop working from the field. | Add `onEditingComplete` and pass it to `EditableText`, or keep focus after submit for single-line fields. The app sends `TextInputAction.unspecified` outside the Android and iOS soft keyboards, which keeps focus. | H3 |
