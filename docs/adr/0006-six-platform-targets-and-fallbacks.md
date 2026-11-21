---
status: accepted
date: 2026-11-21
---

# Six platform targets and their fallbacks

## Context and problem statement

The spec's layout names "responsive Flutter Web + Android/iOS"
(`spec/v4.0/AGENTS.md`, "Proposed monorepo layout"). It does not mention
desktop. The owner wants web, Android, iOS, Linux, Windows and macOS.

Package support differs by platform (pub.dev API and
firebase.google.com/docs/flutter/setup, fetched 2026-11-21):

| Capability | Web | Android | iOS | macOS | Linux | Windows |
| --- | --- | --- | --- | --- | --- | --- |
| `firebase_auth` | yes | yes | yes | yes | no | not for production |
| `youtube_player_iframe` | yes | yes | yes | yes | no | no |
| `just_audio` | yes | yes | yes | yes | needs `just_audio_media_kit` | needs `just_audio_media_kit` |
| pdfrx, file_picker, go_router, flutter_markdown_plus, flutter_math_fork, dio | yes | yes | yes | yes | yes | yes |

The Firebase Auth REST API is documented, so sign-in can be built without the
SDK.

## Decision drivers

- Release 1 (public course reader, M0 to M2b) needs no sign-in.
- V4-CORE-05: web and native must show every viewer type.
- The spec forbids storing tokens in plain local storage
  (`spec/v4.0/docs/ARCHITECTURE.md`, "Browser/native specifics").
- Free CI for a public repository.

## Considered options

- All six platforms, with per-platform fallbacks.
- Web, Android and iOS only, as the spec states.
- Web plus mobile first, desktop later.

## Decision outcome

Chosen option: "all six platforms, with fallbacks".

- Release 1 has no auth, so the Firebase gaps do not affect it.
- Video on Linux and Windows shows a consent-gated "Open in browser" card
  (COOKIE-003 consent gate applies).
- Audio on Linux and Windows adds `just_audio_media_kit`.
- Desktop sign-in (M3) uses a small client for the Firebase Auth REST API.
- CI runners: ubuntu (web, Android, Linux), windows, macos (iOS, macOS).
  They are free for public repositories.

### Consequences

- Good, because one codebase reaches every desktop and mobile target.
- Bad, because the REST sign-in client is code the SDK would otherwise
  provide. Its token storage must use the OS keychain or credential store,
  not preferences. The storage choice is open until M3.
- Bad, because Linux and Windows users get less in video and, until M3, have
  no sign-in.
- Bad, because six CI builds slow every milestone.

### Confirmation

- M2b exit: V4-CORE-05 passes on web and one native platform; manual screen
  reader pass (NVDA, VoiceOver, TalkBack).
- CI builds web, Android, Linux and Windows, then iOS and macOS.

## More information

Plan decision D6. Revisit the Windows `firebase_auth` status at M3.
