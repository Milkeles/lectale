# Architecture decisions

Decisions that are costly to reverse, one file each, in the
[MADR 4.0](https://adr.github.io/madr/) format trimmed to its useful parts
([template](template.md)). See [ADR-0001](0001-record-architecture-decisions.md).

To record a decision, copy the template to the next number, set
`status: proposed`, and open a pull request. The status becomes `accepted`
when the owner agrees. Never edit an accepted record to say something else:
write a new one and mark the old one `superseded by ADR-NNNN`.

Spec defects that need a decision are tracked in
[`spec/errata/ERRATA.md`](../../spec/errata/ERRATA.md).

| ADR | Decision | Status |
| --- | --- | --- |
| [0001](0001-record-architecture-decisions.md) | Record architecture decisions | accepted |
| [0002](0002-one-worker-with-static-assets.md) | One Worker with static assets instead of Pages Functions | accepted |
| [0003](0003-validate-manifests-on-the-server-only.md) | Validate manifests on the server only | accepted |
| [0004](0004-litse-ui-as-a-private-git-dependency.md) | litse-ui (`devchat_ui`) as a private git dependency | accepted |
| [0005](0005-flutter-3-50-and-pinned-toolchain.md) | Flutter 3.50 and a pinned toolchain | accepted |
| [0006](0006-six-platform-targets-and-fallbacks.md) | Six platform targets and their fallbacks | accepted |
| [0007](0007-offline-assessment-records.md) | Offline assessment records for manual grading | accepted |
| [0008](0008-scoped-resource-addresses-and-public-preview-route.md) | Scoped resource addresses and a public preview route | proposed |
| [0009](0009-agent-team-and-model-routing.md) | Agent team and model routing | accepted |
| [0010](0010-feature-intake-gate-and-build-vs-buy.md) | Feature intake gate and build-versus-buy rule | accepted |
