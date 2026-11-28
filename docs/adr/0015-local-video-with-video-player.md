---
status: accepted
date: 2026-11-28
---

# Local course video plays with `video_player`; Linux and Windows open it in the browser

## Context and problem statement

UI-002 and `RENDERING_REQUIREMENTS.md` ask for course video files (MP4) to play in the app with in-app controls. No ADR covered a video package. ADR-0006 already gives Linux and Windows an "Open in browser" card for YouTube, because the embed package doesn't support them. The facts are in [the research note](../research/2026-11-28-local-video-playback.md).

## Considered options

- `video_player` (BSD-3-Clause, Flutter team, Flutter Favorite): web, Android, iOS and macOS. Platform players, no bundled native library. No Linux or Windows.
- `media_kit` with `media_kit_video` (MIT): all six platforms. Bundles or requires libmpv: a system package on Linux, and an 11.6 MB download at Windows build time. libmpv's own licence (GPL or LGPL build) is not verified.
- `fvp`: all six, but its libmdk SDK is closed source.

## Decision outcome

Chosen option: `video_player` on web, Android, iOS and macOS, with our own litse-ui controls in `packages/resource_renderers`. `video_player` imports Material, so its widget stays in `lib/src/adapters/`. On Linux and Windows, video files get the same "Open in browser" card as ADR-0006 gives YouTube. It is the choice with no native binaries, no build-time downloads and no licence question, and it matches the platform split ADR-0006 already made.

### Consequences

- Good, because it adds no native library and no licence risk, and the Flutter team maintains it.
- Good, because the `VideoPlayerPlatform` interface lets `fvp` or a media_kit backend plug in later without changing our controls.
- Bad, because Linux and Windows users watch course videos in their browser.
- To check when built: on the web, seeking needs the Worker to answer Range requests with 206. The preview file route already serves ranges; the viewer's tests must cover seeking.

## More information

Revisit if the owner wants in-app video on Linux and Windows. `media_kit` is the candidate, after its libmpv licence is checked. `just_audio_media_kit` (ADR-0006) may already bring libmpv's audio build to those platforms.
