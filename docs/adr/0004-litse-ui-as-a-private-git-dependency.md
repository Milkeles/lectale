---
status: accepted
date: 2026-11-21
---

# litse-ui (`devchat_ui`) as a private git dependency

## Context and problem statement

Lectale needs an accessible, modern component library on six platforms. The
owner already has one: `devchat_ui` (repository `litse-ui-private`,
Apache-2.0, currently private), built on Flutter's widgets layer with
independent color and style axes (devchat-frontend ADR-0004). Lectale follows
devchat-frontend's conventions: pub workspace, Riverpod, go_router.

The library lacks components Lectale's screens need. The owner decided it
stays private for now. A private dependency affects CI, deploys and outside
contributors.

## Decision drivers

- Reuse the owner's library and add components there, not here.
- CI must fetch it without exposing credentials.
- WCAG 2.2 AA (DEC-12, A11Y-002) on every screen.

## Considered options

- Git dependency on the private repository, pinned by tag.
- Publish `devchat_ui` publicly first.
- Copy the components into Lectale.
- forui or shadcn_ui as the main library.

## Decision outcome

Chosen option: "private git dependency pinned by tag". Releases are cut by
release-please. New components are built in litse-ui, driven by Lectale's
screens. forui and shadcn_ui are API references only.

CI fetches the dependency with a read-only deploy key stored as the
`LITSE_UI_DEPLOY_KEY` GitHub Actions secret. Builds and deploys run in GitHub
Actions with Wrangler, so Cloudflare never needs the key. Pull requests from
forks get no secrets, so they run only the TypeScript and contract jobs. That
is acceptable for a solo project, and the README says so.

First litse-ui work: a reading-oriented `DcStyle` (larger type, relaxed
density, comfortable line length). Then, in order of need: progress, toast,
menu/popover, select, sidebar, breadcrumb, accordion, tree, skip link, sheet,
slider, table, drop zone. litse-ui's CI moves from Flutter 3.47.7 to 3.50.x
first ([ADR-0005](0005-flutter-3-50-and-pinned-toolchain.md)).

Material still arrives transitively through go_router, pdfrx and
youtube_player_iframe (via `material_ui`). It is confined to adapters in
`packages/resource_renderers/lib/src/adapters/` and bridged to `DcTheme`.

### Consequences

- Good, because screens share one design system and one accessibility test
  suite.
- Bad, because fork pull requests cannot build the Flutter app in CI.
- Bad, because every new component needs a litse-ui release before Lectale
  can use it.
- Bad, because a leaked deploy key exposes the library source. The key is
  read-only and scoped to one repository.

### Confirmation

- CI uses the deploy key and has no other path to the dependency.
- `tool/check_rules` fails on `material.dart` imports outside the adapters
  directory.
- zizmor and SHA-pinned Actions guard the workflow that holds the secret.

## More information

Revisit when litse-ui goes public: the deploy key and the fork limit then go
away. The key setup steps are in plan §9 (accounts and access).
