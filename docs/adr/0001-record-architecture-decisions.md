---
status: accepted
date: 2026-11-21
---

# Record architecture decisions as Markdown files in the repository

## Context and problem statement

Lectale is built and run by one person, with Claude and Codex agents doing
much of the work. Agents lose their conversation when a session ends or a
usage limit hits. A decision that lives only in chat is lost, and the next
agent may reverse it without knowing why.

The repository also holds a fixed, imported specification
(`spec/v4.0/`). Where Lectale departs from it, the reason must be written
down next to the code.

## Decision drivers

- Any agent (Claude or Codex) must be able to resume from the repository
  alone.
- Reviewers read the repository, not a wiki.
- The format must match the owner's other projects.

## Considered options

- MADR records in `docs/adr`, as in `Milkeles/devchat-frontend`.
- A decision log in `PLAN.md` only.
- No records; commit messages only.

## Decision outcome

Chosen option: "MADR records in `docs/adr`", because they are versioned with
the code, reviewed in the same pull request, and already the owner's
convention.

Each record is one file named `NNNN-short-title.md`, numbered without gaps.
It starts with YAML front matter (`status`, `date`) and uses
[`template.md`](template.md), copied from devchat-frontend. Statuses are
`proposed`, `accepted`, `rejected` and `superseded by ADR-NNNN`. An accepted
record is never edited to say something else; a new record supersedes it.

Spec errata that need the owner's sign-off go in
[`spec/errata/ERRATA.md`](../../spec/errata/ERRATA.md). An erratum that
changes the architecture also gets an ADR, and the register links to it.

### Consequences

- Good, because a decision and its reasons sit next to the code.
- Good, because a fresh agent session can read `docs/adr/README.md` and know
  the standing decisions.
- Bad, because records need discipline: a decision taken in a pull request
  without a record is invisible.

### Confirmation

Reviewers reject a pull request that changes the architecture without an
ADR. M0 should add a numbering and index check modelled on
`.github/scripts/check-adrs.sh` in devchat-frontend. It does not exist yet.

## More information

Template and index format: devchat-frontend `docs/adr/` (ADR-0001). The
feature intake gate that decides when a record is needed is in
[ADR-0010](0010-feature-intake-gate-and-build-vs-buy.md).
