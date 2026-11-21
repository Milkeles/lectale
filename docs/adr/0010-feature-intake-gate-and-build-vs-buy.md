---
status: accepted
date: 2026-11-21
---

# Feature intake gate and build-versus-buy rule

## Context and problem statement

The spec is large: payments, auto-grading, a catalog, compliance. A solo
owner with agents can build far more than should exist. Each feature adds
code to maintain, attack surface and cost. Agents also tend to write what a
library already does.

Lectale's goals are low recurring cost, low operating burden and verified
security and accessibility. The spec's definition of done requires a trace
matrix linking each requirement to tests and commits
(`spec/v4.0/docs/RELEASE_TESTS_V4.md`, "Deliverability";
`spec/v4.0/FULL_SPECIFICATION.md` §24).

## Decision drivers

- Every task traces to a requirement ID.
- Prefer existing, maintained libraries to new code.
- State survives a lost chat session.

## Considered options

- A gate block at the top of every task, plus a build-versus-buy rule.
- Review at pull request time only.
- No formal gate.

## Decision outcome

Chosen option: "gate block plus rule". The orchestrator writes each task as an
agent task specification (from `software-doc-templates/ai-assisted-development`)
that opens with this block. A task that cannot fill in "Why" is dropped.

```
Why:        requirement IDs (V4-*, SEC-*, A11Y-*, spec §) it satisfies. None: drop it.
Simpler:    smallest version that meets them; what we are NOT building.
Ready-made: difficulty S/M/L/XL + estimated LOC. Over 200 LOC or a well-known
            problem: link a researcher note or an ADR exception.
Security:   trust boundaries touched, SEC/V4-SEC IDs, review required?
Verify:     exact command(s) + expected result; acceptance IDs this closes.
```

Build versus buy: before writing more than about 200 lines, the researcher
rates difficulty and looks for an existing solution. The note records fetched
sources, licence, maintenance and runtime fit (for Workers: no `eval`, no
Node-only APIs). Facts come from fetched pages, never memory, and are stored
in `docs/research/` with URL and date.

The one exception so far: the `.ipynb` renderer (about 500 lines). No Dart
package exists, and notebookjs is web-only and an XSS route. It gets its own
ADR when built.

State lives in the repository: `PLAN.md` (queue and blockers),
`spec/tasks/*.md` (active task specs), `docs/adr/`, `docs/research/`,
`docs/traceability.md` and `spec/INDEX.md`.

### Consequences

- Good, because scope stays tied to the spec and out-of-scope work is named.
- Good, because library choices are evidence-based and reusable.
- Bad, because every task costs a few minutes of gate writing.
- Bad, because research notes go stale. Each carries its fetch date.

### Confirmation

- Reviewers reject a pull request whose task spec has no filled gate.
- `docs/traceability.md` has a test for every acceptance ID that a merged
  milestone claims.
- Dependencies over 200 lines of replaced code link a research note.

## More information

Verified choices from the first research round are in the plan (§1.2).
Related: [ADR-0001](0001-record-architecture-decisions.md),
[ADR-0009](0009-agent-team-and-model-routing.md).
