# Local video playback, build vs buy (2026-11-28)

Need: play course MP4 (maybe WebM) from a same-origin, Range-capable URL inside the Flutter app, with our own controls, on web, Android, iOS, Linux, Windows and macOS.
Requirement IDs: UI-002 (`spec/v4.0/FULL_SPECIFICATION.md:659`), RENDERING_REQUIREMENTS video row ("HTML5 player for playable media files"), V4-CORE-05, ADR-0006.
Constraints checked: Workers (not applicable, client only) / six platforms / litse-ui / MIT / cost

All pub.dev data fetched 2026-11-28 from `https://pub.dev/api/packages/<name>` and `/score`. README and source quotes from raw.githubusercontent.com, fetched 2026-11-28. Two repo facts: ADR-0006 currently says video on Linux and Windows is an "Open in browser" card, so any option that plays natively there changes that ADR.

## Candidate: video_player (official, flutter/packages)
- Source URLs: https://pub.dev/api/packages/video_player ; .../score ; https://raw.githubusercontent.com/flutter/packages/main/packages/video_player/video_player/README.md ; https://raw.githubusercontent.com/flutter/packages/main/packages/video_player/video_player_web/README.md
- Version and date: 2.14.1, published 2026-10-02
- Licence: BSD-3-Clause (`license:bsd-3-clause` in /score). Compatible.
- Maintenance: Flutter Favorite (`is:flutter-favorite`), 3730 likes, 4,359,409 downloads in 30 days. Last push and open issues: not verified.
- Platforms (/score tags): android, ios, macos, web. No `platform:linux`, no `platform:windows`. README table: "Android SDK 24+, iOS 15.0+, macOS 12.0+, Web Any*".
- Minimum Flutter: `flutter >=3.44.0`, `sdk ^3.12.0` (pubspec). ADR-0005 pins Flutter 3.50, so fine.
- Controls and Material: the package ships no controls UI. The README example wraps `VideoPlayer(_controller)` in `MaterialApp`/`Scaffold`, but that is the example only. `video_player.dart` imports `package:flutter/material.dart` (line 11, for `VideoProgressIndicator` and similar helpers); the plain `VideoPlayer` widget does not need it. We build controls in devchat_ui. Whether the Material import costs anything at runtime: not verified.
- Range and streaming from URL: ExoPlayer on Android and AVPlayer on iOS/macOS back it ("On Android, the backing player is ExoPlayer ... On iOS and macOS, the backing player is AVPlayer"). Range behaviour of those players: not verified. On web the README states: "Certain videos will rewind to the beginning when users attempt to seekTo ... the server ... doesn't support HTTP range requests", and "Flutter web's local server ... DOES NOT support range requests". So our Range-capable same-origin URL is a hard requirement on web.
- Web implementation: browser element. "available formats depend on your users' browsers". The web package is an endorsed federated plugin, deps include `video_player_web`. The README does not say "HTML video element" in so many words; element type: not verified from README, but the Range/seek text and autoplay text describe browser media element behaviour. Third-party network use: none stated.
- Linux and Windows: not supported. Fallback exists as a separate package (see fvp below) or the ADR-0006 "Open in browser" card.
- Native size added: not applicable (uses platform players); not verified.
- Cost: free.
- Lock-in: low. `VideoPlayerPlatform` interface is the replacement seam (fvp and video_player_media_kit plug into it).
- Remaining glue: about 150 lines for devchat_ui controls (play/pause, seek, time, fullscreen), plus a registry entry.

## Candidate: media_kit + media_kit_video + media_kit_libs_video
- Source URLs: https://pub.dev/api/packages/media_kit ; /media_kit_video ; /media_kit_libs_video ; /media_kit_libs_linux ; /media_kit_libs_windows_video (each with /score) ; https://raw.githubusercontent.com/media-kit/media-kit/main/README.md ; .../libs/windows/media_kit_libs_windows_video/windows/CMakeLists.txt ; .../libs/linux/media_kit_libs_linux/linux/CMakeLists.txt ; .../media_kit_video/lib/src/video/video.dart, video_texture.dart, video_web.dart ; https://raw.githubusercontent.com/mpv-player/mpv/master/Copyright ; HEAD request on the libmpv archive URL
- Versions and dates: media_kit 1.2.6 (2025-12-13); media_kit_video 2.0.1 (2025-12-02); media_kit_libs_video 1.0.7 (2025-10-05, tagged `is:unlisted`); media_kit_libs_linux 1.2.1 (2025-03-24); media_kit_libs_windows_video 1.0.11 (2025-03-24). The libs packages are unlisted and not discontinued (`isDiscontinued` null).
- Licence: MIT for all five (`license:mit`; README "governed by MIT license"). The bundled native library is a separate matter: mpv's Copyright file says "mpv as a whole is licensed under the GNU General Public License GPL version 2 or later ... by default ... LGPL ... if built without using any GPL only files". Which mpv/FFmpeg configuration media_kit ships on Windows and Linux (GPL or LGPL): NOT VERIFIED. On Linux the README says system libmpv is used, so we would not redistribute it. On Windows the app bundle would redistribute libmpv. This needs an owner or legal decision before shipping.
- Maintenance: repo media-kit/media-kit pushed 2026-11-23, archived False, MIT, 1856 stars, 376 open issues (GitHub search API). Last pub release is about 11 months old (media_kit 2025-12-13, libs 2025-03/10). Downloads 30 days: media_kit 448,182; media_kit_video 343,485. Pub points for media_kit_video: 140 of 160.
- Platforms (/score): android, ios, windows, linux, macos, web for media_kit, media_kit_video and media_kit_libs_video. README table lists video support on all six.
- Minimum Flutter: media_kit_video `flutter >=3.7.0`, `sdk >=2.17.0 <4.0.0`; media_kit `sdk >=3.1.0 <4.0.0`. Fine with Flutter 3.50.
- Controls and Material: `Video` defaults to `controls = AdaptiveVideoControls` (Material or Cupertino by platform; `video_texture.dart` line 130). The README lists `NoVideoControls`: "Disable video controls i.e. only render video output." So pass `NoVideoControls` and build controls in devchat_ui from `player.stream` and `player.state`. The package's own control files import Material and are compiled in, but app screens do not use them. Whether `Video` itself needs a `Material` ancestor with `NoVideoControls`: not verified.
- Range and streaming: the README shows `Media('https://...mp4', httpHeaders: {... 'Range': 'bytes=0-'})`, i.e. network URLs and custom headers are supported. Native Range/seek behaviour of libmpv on HTTP: not verified. On web the browser element decides, so the same Range requirement as above applies.
- Web implementation: "On the web, libmpv is not used. Video & audio playback is handled by embedding HTML `<video>` element. The format support depends upon the web browser. It happens to be extremely limited as compared to native platforms." Source: README. Third-party network use at runtime on web: none found in the README or `video_web.dart` imports; a full code audit was not done.
- Linux: system libmpv. "System shared libraries from distribution specific user-installed packages are used by-default." Install line `sudo apt install libmpv-dev mpv`. So the user (or our package: deb/Flatpak/Snap) must supply libmpv; not bundled by default. The README also recommends mimalloc to avoid leaks. Added size: not verified. `media_kit_libs_linux` downloads mimalloc at build time (it has `download_and_verify` with MD5; URL not read).
- Windows: `media_kit_libs_windows_video` CMake downloads at build time from GitHub: `https://github.com/media-kit/libmpv-win32-video-cmake/releases/download/20241021/mpv-dev-x86_64-20241021-git-0f78584.7z` (MD5 pinned) and `https://github.com/alexmercerind/flutter-windows-ANGLE-OpenGL-ES/releases/download/v1.0.1/ANGLE.7z` (MD5 pinned). The x86_64 libmpv archive is 11,601,537 bytes (Content-Length on HEAD, 2026-11-28); unpacked size in the app: not verified. Build machines and CI need access to github.com; the libmpv build is dated 2024-10-21.
- Platform notes (README): Android 5.0+, iOS 9+, macOS 10.9+, Windows 7+.
- Cost: free.
- Lock-in: medium. The `Player`/`Video` API is its own; but it is already planned for audio on Linux and Windows through `just_audio_media_kit` (ADR-0006), so libmpv would be shipped anyway there. I did not fetch just_audio_media_kit's metadata in this run, so "already coming in" is the brief's statement, not verified here.
- Remaining glue: about 200 lines for devchat_ui controls, `NoVideoControls`, Player lifecycle and `MediaKit.ensureInitialized()`, plus Linux packaging of libmpv.

## Candidate: video_player + fvp (backend for Linux and Windows only)
- Source URLs: https://pub.dev/api/packages/fvp ; /fvp/score ; https://raw.githubusercontent.com/wang-bin/fvp/master/README.md ; .../LICENSE ; https://raw.githubusercontent.com/wang-bin/mdk-sdk/master/README.md ; https://raw.githubusercontent.com/wang-bin/fvp/master/cmake/deps.cmake
- Version and date: fvp 0.40.0, published 2026-11-06
- Licence: the plugin is BSD-3-Clause. The native SDK it downloads (libmdk) is not shown as open source: mdk-sdk README "License: Free for opensource projects ... Free for Flutter users. A key is already included. Can be commercial softwares. ... Commercial license for other users". Terms of that grant and redistribution rights: not verified in full. This is not an MIT/BSD/Apache licence; treat as unknown until the owner decides.
- Maintenance: 179 likes, 36,289 downloads in 30 days. Last push, issues: not verified.
- Platforms (/score): android, ios, linux, macos, windows. No web tag (web comes from video_player itself). README: "Windows x64 ... and arm64, Linux x64 and arm64".
- Minimum Flutter: `>=3.22.0`, `sdk ^3.4.0`. README: "Since flutter 3.27, fvp must be a direct dependency".
- Material: none; it is a `VideoPlayerPlatform` implementation, so our controls are the same ones as for video_player.
- Range and streaming: not verified.
- Third-party network use: the build downloads the SDK from SourceForge (`https://sourceforge.net/projects/mdk-sdk/files/nightly` in `deps.cmake`), with optional `FVP_DEPS_URL` and `FVP_DEPS_SHA256` to pin a mirror. Pinning is possible.
- Size: "Small footprint. Only about 10MB size increase per cpu architecture(platform dependent)." (README, vendor claim).
- Default behaviour: "Without this step, this plugin will be used for video_player unsupported platforms(windows, linux), official implementation will be used otherwise." So official players run on Android, iOS, macOS and web.
- Cost: free for Flutter users per the SDK README; no key needed.
- Lock-in: low (same `video_player` API). Remaining glue: one `registerWith` call plus the same controls as video_player.

## Others looked at, not recommended
- video_player_media_kit 2.0.0 (2025-11-14, MIT, all six platform tags): a `video_player` backend on media_kit; 44,803 downloads. https://pub.dev/api/packages/video_player_media_kit . It gives the video_player API with libmpv on desktop. Not examined further.
- video_player_win 3.3.2 (2026-11-22, BSD-3-Clause): Windows only. Does not cover Linux.
- chewie 1.18.1 and better_player_plus 2.0.1: both depend on `material_ui`, and better_player_plus is android and ios only. Both ruled out by the Material rule and platform tags.
- Not looked at: flutter_vlc_player / libvlc based packages and webview based players.

## Recommendation
Use `video_player` for web, Android, iOS and macOS, with our own devchat_ui controls. Keep the ADR-0006 "Open in browser" card on Linux and Windows for now, and revisit with a second option when the owner decides on libmpv.

Reason: it is the only candidate with a plain BSD licence, no native binaries, no build-time downloads and no libmpv GPL/LGPL question, and it covers all four platforms where UI-002 says "Flutter Web/mobile". Cost of this choice: Linux and Windows get no in-app video, which ADR-0006 already accepts, so the spec line holds. Own code is about 150 lines for controls.

If the owner wants in-app video on Linux and Windows (a spec extension, not required by UI-002): needs owner decision between (a) media_kit via `video_player_media_kit` or directly, costing a libmpv dependency (Linux: user-installed `libmpv-dev`; Windows: an 11.6 MB archive downloaded from GitHub at build time) and an open GPL/LGPL check, which ties in with `just_audio_media_kit` already planned for audio; and (b) fvp, which is small (about 10 MB) but uses a closed-source SDK under a custom "free for Flutter users" grant, which does not meet the MIT-compatible licence rule as written.

Server requirement for all options on web: the video URL must answer Range requests with 206 (video_player_web README). Test this in our Worker's static-asset and LFS path before relying on seek.

## Not verified
- Range/seek behaviour of ExoPlayer, AVPlayer and libmpv on HTTP URLs.
- Whether media_kit's Windows libmpv build is GPL or LGPL, and the unpacked sizes on Linux and Windows.
- Open issues and last push for flutter/packages and fvp; GitHub repo endpoints are refused for unattached repos.
- WebM support: browser-dependent on web (README points to caniuse); native support per backend not read.
- just_audio_media_kit details (not fetched in this run).
