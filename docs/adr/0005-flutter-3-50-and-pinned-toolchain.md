---
status: accepted
date: 2026-11-21
---

# Flutter 3.50.1 and a pinned toolchain

## Context and problem statement

Flutter stable is 3.50.1 (released 2026-11-20). The docs.flutter.dev
breaking-changes page and the Flutter release feed, fetched 2026-11-21, say
the Material and Cupertino libraries inside the SDK are formally deprecated in
3.50. `MaterialUiCompatibilityBridge` covers third-party packages that still
use them.

Lectale's dependencies set the floor: pdfrx needs Flutter 3.50 and pulls in
`material_ui`; forui, kept as an API reference, needs 3.50 or newer.
litse-ui's CI currently runs 3.47.7 ([ADR-0004](0004-litse-ui-as-a-private-git-dependency.md)).
The owner's convention is exact pins (devchat-frontend ADR-0010).

## Decision drivers

- pdfrx is the only PDF viewer found that covers all six platforms.
- Every agent and CI runner must build the same way.
- Upgrades must be deliberate, not a side effect.

## Considered options

- Pin Flutter 3.50.1, Node LTS and Wrangler in `.config/mise.toml`.
- Stay on 3.47.x and skip pdfrx.
- Track the `stable` channel.

## Decision outcome

Chosen option: "pin Flutter 3.50.1, Node LTS and Wrangler in
`.config/mise.toml`". litse-ui moves to 3.50.x first and tags a release
before Lectale depends on it. Flutter upgrades are their own pull request.
just recipes and CI read versions from mise.

### Consequences

- Good, because local, agent and CI builds match.
- Good, because the Material deprecation is handled once, in the
  `resource_renderers` adapters.
- Bad, because the pin is one day old. Early 3.50.x patch releases may break
  packages. Bump to the next patch only after CI passes.
- Bad, because litse-ui work must land before M0's CI can be green.

### Confirmation

- CI runs `mise install` and fails if the Flutter version differs from
  `.config/mise.toml`.
- The M0 exit criterion: CI green on an empty app on all six platforms.

## More information

Plan decision D7. Revisit when Flutter 3.51 ships or a dependency drops
3.50 support.
