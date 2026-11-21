# Planning screens

No screen is coded until its spec in `docs/ux/screens/` has passed review. The spec is a wireframe written for both people and agents: structured text plus ASCII layouts, cheap to change before any widget exists.

## Steps

1. **Journeys.** List the user journeys the milestone serves, from the spec's actors and release cases (for example V4-CORE-01: open a public course by URL).
2. **Screen inventory.** One line per screen: its single purpose and the journeys it serves. If two screens serve the same purpose, merge them.
3. **Screen spec.** Copy `screen-spec-template.md` to `screens/<screen>.md` and fill it in. Every element must name the user task it serves; an element without one is removed.
4. **Review before code.** The design-reviewer checks the spec against the `screen-spec` skill (UX laws and anti-patterns). Codex gives a second opinion. Fix the spec, not the code.
5. **Build.** The frontend-engineer implements the spec with litse-ui components.
6. **Visual review.** The design-reviewer compares screenshots with the spec (`visual-review-loop` skill).

A change to a screen's purpose, primary action or element list goes back through step 4.
