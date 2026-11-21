---
name: lectale-docs
description: Documentation and code-comment standards for Lectale. Use when writing or reviewing ADRs, threat model, traceability matrix, runbooks, ROPA, retention policy, incident response plan, accessibility statement or test plan, release notes, agent task specifications, README text, Dartdoc or TSDoc comments, or any inline comment. Gives the owner's writing principles, which template to use when, and a banned-phrase list.
---

# Lectale docs and comments

Documentation supports development. A document that does not help someone build, run, test or decide is cost, so write it short and keep it next to the thing it describes.

## Writing principles (owner's, from software-doc-templates/CONTRIBUTING.md)

- Write for understanding, not to impress.
- Put the important information first.
- Use plain language. No jargon unless the audience already knows it.
- Short sentences. Short paragraphs. Active voice.
- Be specific: concrete details, examples, numbers.
- Say what the reader gains, not just what a thing is.
- Address objections directly instead of hoping nobody raises them.
- Cut every word that doesn't change the meaning. Then re-read and cut again.

Templates are at `/home/user/milkeles/software-doc-templates` (index in `INDEX.md`). Copy the template, fill every section, delete the italic guidance. Headings must survive that deletion. Every document names an owner (a person), a last-reviewed date, a review cadence and one location.

## Which document, when

| Need in Lectale | Template (under software-doc-templates/) | Home |
|---|---|---|
| A significant decision, including each spec erratum and each ADR exception to the 200-line rule | `general-swe/foundations/architecture-decision-record.md` | `docs/adr/`, MADR style |
| What an attacker would go for | `general-swe/foundations/threat-model.md` (STRIDE, from SECURITY_TESTS and SESSION_SECURITY) | `docs/threat-model.md`; every task's Security field updates it |
| Requirement to test to commit proof | `general-swe/waterfall/requirements-traceability-matrix.md` | `docs/traceability.md` |
| Fixing a failure at 3am (token rotation, D1 restore, webhook outage) | `general-swe/foundations/runbook.md` | `docs/runbooks/`, next to the code it operates |
| What personal data is held, why, where it goes (GDPR Art. 30) | `general-swe/security-and-compliance/record-of-processing-activities.md` | `docs/compliance/` |
| How long each kind of data is kept | `.../security-and-compliance/data-retention-policy.md` | `docs/compliance/`; the cron job implements it |
| Who does what in a breach, notification clock | `.../security-and-compliance/incident-response-plan.md` | `docs/compliance/` |
| Risky new processing (certificates, catalog) | `.../security-and-compliance/data-protection-impact-assessment.md` | `docs/compliance/`, before the build |
| What the product does for users who cannot use it as most do | `web-development/accessibility/accessibility-statement.md` | published in the app |
| How accessibility is tested | `web-development/accessibility/accessibility-test-plan.md` | `docs/a11y/` |
| Telling users what changed | `general-swe/foundations/release-notes.md` for the human text; release-please generates the changelog from commits | GitHub releases, `CHANGELOG.md` |
| Handing a task to an agent | `ai-assisted-development/specification/agent-task-specification.md`, opened with the intake gate (Why, Simpler, Ready-made, Security, Verify) | `spec/tasks/`, archived when merged |
| Agent standing rules and the work queue | `ai-assisted-development/foundations/agent-instructions-file.md`, `task-plan.md` | `AGENTS.md`, `PLAN.md` at the repo root |

A changelog (what changed, for integrators) and release notes (what you can now do, for users) are two documents for two readers. Do not merge them. Skip a template when the group README says to; say so in the ADR rather than writing an empty file.

## Code comments

Dart follows Effective Dart documentation; TypeScript follows TSDoc.

- Public APIs get a doc comment (`///` in Dart, `/** */` in TypeScript) covering: purpose, contract (inputs, outputs, errors), edge cases, and the spec ID when one applies (`/// Enforces SEC-021: ...`).
- First sentence is a short summary ending in a period, in its own paragraph. Tools use it as the list summary.
- Functions with side effects start with a third-person verb ("Deletes the file"). Properties start with a noun phrase; booleans with "Whether".
- Dart: describe parameters, returns and exceptions in prose, with `[name]` for identifiers. Do not use `@param`/`@returns` tags. Use `//` for ordinary comments, not `/* */`.
- TypeScript: TSDoc tags are `@param name - description`, `@returns`, `@throws`, `@remarks` (detail after the summary), `@defaultValue`, `@deprecated`.
- Inline comments say why: the constraint, the trade-off, the bug avoided. They never narrate what the next line does. If a comment restates the code, delete it.
- Do not document a private member unless the reason is not obvious from the code.

### Banned phrases

"This function...", "This class...", "robust", "seamless" and "seamlessly", "leverage", "comprehensive", "ensure that", "it's worth noting", "delve", decorative section banners (`// ------ Helpers ------`), emoji. They add no meaning and mark text as machine-written. Replace with the specific fact.

### Good, from `litse-ui-private/lib/src/components/tooltip.dart`

```dart
/// A short description of a control, shown on hover, on focus and on a
/// long press.
///
/// The first tooltip appears after [hoverDelay]; while one is showing, the
/// next one opens at once. Assistive technologies read the message together
/// with the control, so [child] should be a single control.
```

```dart
// Merged, the control and its tooltip are one node, which screen
// readers announce as "Copy, Copy the link" instead of two stops.
```

The summary is a noun phrase, the edge case is stated, and the inline comment gives a reason a reader cannot see in the code.

### Bad, a rewrite of the same code

```dart
/// This class provides a robust and comprehensive tooltip widget that
/// seamlessly leverages the framework to ensure that users can easily
/// see helpful information.
```

```dart
// ===== Build method =====
// Wrap the child in MergeSemantics
```

Every phrase is a banned word or restates the code, and none says what the tooltip does or why the semantics are merged.

## Checks before finishing

Read the text aloud against the principles. Search for banned phrases. Confirm each external fact has a source URL and date. Run `typos` and markdownlint if configured.

Sources: /home/user/milkeles/software-doc-templates (CONTRIBUTING.md writing principles, INDEX.md, and the README files of general-swe/foundations, general-swe/security-and-compliance, web-development/accessibility, ai-assisted-development); Effective Dart documentation, raw.githubusercontent.com/dart-lang/site-www/main/src/content/effective-dart/documentation.md; TSDoc tag definitions from raw.githubusercontent.com/microsoft/tsdoc/main/tsdoc/src/details/StandardTags.ts (tsdoc.org was unreachable from this environment, so TSDoc page text was not read); raw.githubusercontent.com/googleapis/release-please/main/README.md (changelog from Conventional Commits); /home/user/litse-ui-private/lib/src/components/tooltip.dart. All fetched 2026-11-21. Note: the folder is general-swe/security-and-compliance, not a top-level group.
