---
name: ui-copy
description: Write or review interface copy for Lectale: button labels, headings, empty states, error messages, form hints, onboarding text, consent and notice wording, and the not-found message for private or missing repositories. Use whenever a screen adds or changes visible text, or when the copywriter agent is dispatched. Covers plain language for learners of any discipline.
---

# Interface copy

Words in an interface exist to make it easier to understand and use. Lectale's readers are learners and instructors of any discipline, many reading in a second language, so write for the least technical of them.

## Writing principles

These are the owner's principles (`software-doc-templates/CONTRIBUTING.md`, "Writing principles"). Apply them to every string.

- Write for understanding, not to impress.
- Put the important information first.
- Plain language; no jargon unless the audience already knows it.
- Short sentences, short paragraphs, active voice.
- Be specific: concrete details, examples, numbers.
- Say what the reader gains, not just what a thing is.
- Answer objections directly instead of hoping nobody raises them.
- Cut every word that does not change the meaning. Then re-read and cut again.

## Rules for interface text

- **Sentence case** everywhere: "Open a course", not "Open A Course". No all-caps labels, no eyebrow label above a heading unless it carries information.
- **Verbs on buttons.** Say what happens: "Save changes", "Open course", "Enrol". Never "Submit", "OK" or "Click here". Buttons are 1 to 3 words.
- **One name per action.** The button "Publish" leads to a confirmation that says "Published". Keep names the same across the flow, and across languages of the app.
- **Name things by what the person understands**, not by how the system works: "course" and "lesson", not "repository tree" or "manifest". Say "GitHub repository" only where the person must paste a link.
- **Plain verbs, no filler.** Skip "please", "simply", "just", "successfully", "Oops!". No exclamation marks. No arrows or decoration appended to labels.
- **Describe, do not sell.** "Read the README and lessons in the app" beats "Unlock a seamless learning experience".
- **Links** say where they go: "Read the privacy notice", not "here".
- **Numbers and units** are specific: "PDF, 2.4 MB", "12 lessons".
- **Placeholders are examples, not labels.** Every input has a visible label; the placeholder shows format ("https://github.com/owner/course").
- **Each element does one job.** A heading names, a line of body text explains, a button acts.

## Errors

Say what happened and how to fix it, in the interface's voice. Do not apologise, blame the person, or be vague. Order: what happened, why if known, what to do next.

| Avoid | Write |
| --- | --- |
| "Something went wrong." | "We could not load this lesson. Check your connection and try again." |
| "Invalid input" | "Enter a GitHub link like https://github.com/owner/course." |
| "Error 429" | "Too many requests. Wait a minute, then try again." |
| "Upload failed!" | "The file is larger than 50 MB. Choose a smaller file or compress it." (use the real limit) |

Match the error's tone to the stakes: a short factual line for validation, one more sentence for failures the person cannot fix themselves, and say who can (the instructor, support).

## Private or missing repositories

When a pasted repository is private or does not exist, the spec requires the same privacy-neutral message either way, so the text must not reveal whether a private repository exists (`spec/v4.0/docs/CORE_EXPERIENCE_AND_CATALOG.md`). Do not vary wording, timing hints or options by case. Example:

> We could not open this course. Check that the link is correct and that the repository is public. If you own it, sign in to connect it.

Never write "This repository is private" or "Repository not found" as separate messages. The sign-in route for owners is offered in both cases.

## Empty states and loading

An empty screen is an invitation to act: say what belongs here and give the one next step. "No courses yet. Paste a GitHub link to open one." Loading uses `DcSkeleton` or `DcSpinner` with a `semanticLabel` such as "Loading lesson", not a message.

## Learners of any discipline

- Prefer everyday words: "open", "read", "hand in", "grade". Explain a technical term once, in place, when the subject needs it (for example "notebook: a document that mixes text and code").
- No metaphors or idioms that translate badly. Dates and numbers follow the locale.
- Keep reading-level low in navigation and notices; course content is the instructor's, not ours.

## Privacy, consent and conversion

Notices and consent text state what is collected, why, and how to refuse, in two or three short sentences. Refusing must never block unrelated course access (COOKIE-005). Do not use dark patterns: no pre-ticked boxes, no guilt wording, equal prominence for Accept and Reject.

The spec's default is no tracking (PRIV-002, V4-COST-06). Conversion tactics that need analytics, cookies or A/B tests are therefore **off by default**. Use only what needs no measurement: customer language, one clear value statement per screen, and answering objections in the copy ("Free to read. No account needed."). Treat any request for tracked experiments as a spec change that goes to the owner first.

## Before handing off

Read each string aloud against the principles; delete words; check sentence case and button verbs; confirm errors include the fix; confirm the private-repository text is identical for both cases.
