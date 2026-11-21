# Client update notices and downloads, build vs buy (2026-11-21)

Need: installed Lectale clients notice a new GitHub release, tell the user, and fetch the right file for their platform, verified before it is offered or installed.   Requirement IDs: none assigned yet; threat model row 7.3 (supply chain) is the nearest. Needs a spec ID or a new row before building.
Constraints checked: Workers (client-side feature, Worker unchanged) / six platforms / litse-ui / MIT / cost

Every fact below was fetched on 2026-11-21. "Not verified" means the page was unreachable or did not say it. Estimates of lines of code are mine, not sourced.

## Hosts that blocked me

The proxy answered "403 Forbidden (agent proxy: no rule or network setting allows this host)" or the fetch failed (HTTP 000) for these hosts. Where a workaround worked, it is named.

| Host | Effect | Workaround |
|---|---|---|
| support.google.com, play.google.com, policies.google.com | Google Play policy text unreachable | none; Play facts are "not verified" |
| support.apple.com | Gatekeeper behaviour page unreachable | developer.apple.com pages |
| learn.microsoft.com | Windows pages unreachable | raw.githubusercontent.com/MicrosoftDocs/windows-dev-docs (source of the same docs) |
| docs.flathub.org, docs.flatpak.org, docs.appimage.org | unreachable | raw GitHub of flathub-infra/documentation, flatpak/flatpak-docs, AppImage/AppImageSpec |
| docs.velopack.io | unreachable | raw GitHub of velopack/velopack.docs |
| source.android.com, sparkle-project.org, web.archive.org, r.jina.ai | unreachable | none |

## 1. Store and platform rules

| Question | Finding | Source |
|---|---|---|
| Google Play: apps that update themselves outside Play | **Not verified.** Policy page blocked. Lectale has no Play listing, so it only matters if the owner adds one. Recheck then. | support.google.com (blocked) |
| Apple App Review 2.5.2 | "Apps should be self-contained in their bundles, and may not read or write data outside the designated container area, nor may they download, install, or execute code which introduces or changes features or functionality of the app, including other apps." Educational apps that teach code may download code only in limited circumstances. A release notice that links out is not code download; an iOS self-updater is. | https://developer.apple.com/app-store/review/guidelines/ |
| Android sideload: permission | `REQUEST_INSTALL_PACKAGES`: "Allows an application to request installing packages. Apps targeting APIs greater than 25 must hold this permission in order to use Intent.ACTION_INSTALL_PACKAGE." Protection level: signature. | https://developer.android.com/reference/android/Manifest.permission |
| Android sideload: user confirmation | A `PackageInstaller` commit "may require user intervention to complete the installation", except for a device owner or affiliated profile owner. `STATUS_PENDING_USER_ACTION`: "User action is currently required to proceed. You can launch the intent activity described by Intent.EXTRA_INTENT". So a normal app cannot install silently. | https://developer.android.com/reference/android/content/pm/PackageInstaller |
| Android: key changes between versions | "As part of Android's secure update model, the signing key never changes during the lifetime of your app." "Android requires that all APKs be digitally signed with a certificate before they are installed on a device or updated." Rotation needs APK Signature Scheme v3, "linking the APK file's past signing certificates to the one with which it is now signed". The exact error text for a mismatched key is **not verified**. | https://developer.android.com/studio/publish/app-signing ; https://developer.android.com/about/versions/pie/android-9.0 |
| Android: debug key | "The first time you run or debug your project in Android Studio, the IDE automatically creates the debug keystore and certificate in $HOME/.android/debug.keystore". A fresh CI runner has no such file, so each CI debug APK can carry a different key (inference from the quote, not tested). A stable release keystore is a precondition for any APK update. | https://developer.android.com/studio/publish/app-signing |
| Android developer verification (new, affects sideloading) | "Protections begin for all users who install apps from participating stores in Brazil, Indonesia, Singapore, and Thailand on certified devices running Android 8 (API level 26) or higher" on 2026-09-30. "Verification capability will be expanded globally for all apps on certified Android devices in 2027." For direct sideloads the FAQ says "these new verification requirements won't apply to your app yet", but "plan to complete your verification before the global rollout begins in 2027". Unregistered apps "can only be installed or updated when the advanced flow is enabled or by using ADB" (advanced flow has a one-time 24-hour wait). | https://developer.android.com/developer-verification ; https://developer.android.com/developer-verification/guides/faq |
| Android verification: cost | "The $25 fee for the Full Distribution account in the ADC helps cover administrative costs". Limited distribution account: "This account is free", for "Share apps with up to 50 devices" (the overview page says 20; the two pages disagree). Requires a Google Account with 2-step verification and a payments profile. | https://developer.android.com/developer-verification/guides/faq ; .../guides/limited-distribution |

## 2. Candidates

Platform tags and licences come from `https://pub.dev/api/packages/<name>/score`; repository data from the GitHub search API. Open-issue counts include pull requests.

### Candidate: auto_updater (leanflutter)
- Source URLs: https://pub.dev/api/packages/auto_updater ; https://raw.githubusercontent.com/leanflutter/auto_updater/main/README.md
- Version and date: 1.0.0, published 2024-10-27
- Licence: MIT (WinSparkle and Sparkle licences not checked, not verified)
- Maintenance: last push 2026-11-15, not archived, 45 open issues, 85,541 downloads in 30 days
- Platform evidence: tags `platform:windows`, `platform:macos` only. README: "Linux ➖ macOS ✔️ Windows ✔️". "based on sparkle and winsparkle".
- Verification: Sparkle appcast model; signature mechanics are in Sparkle docs, which I could not fetch (sparkle-project.org blocked): not verified.
- Cost: free; macOS needs a signed app for a real flow (not verified here).
- Lock-in: medium. It needs an appcast feed that the release job must generate.
- Remaining glue: about 120 lines Dart plus appcast generation in CI. Needs a `devchat_ui` wrapper for any notice, since the Sparkle dialog is native.
- Verdict: no Linux, no mobile. Later option for Windows and macOS once certificates exist.

### Candidate: desktop_updater (MarlonJD)
- Source URLs: https://pub.dev/api/packages/desktop_updater ; https://raw.githubusercontent.com/MarlonJD/flutter_desktop_updater/main/README.md
- Version and date: 3.2.12, published 2026-11-17
- Licence: MIT
- Maintenance: last push 2026-11-17, not archived, 0 open issues, 15,682 downloads in 30 days, 55 likes
- Platform evidence: tags `platform:windows`, `platform:linux`, `platform:macos`. README: "Flutter desktop updater plugin for macOS, Windows, and Linux."
- Verification: strongest of the ready-made options. "Clients fetch exact URLs and verify the artifact length and SHA-256 before installation." Metadata is signed: "Each release must authenticate against one of the pinned Ed25519 release keys".
- Constraints: needs its own feed (`app-archive.json` -> `release.json` -> `app.zip`), published by its CLI to a host you choose; a GitHub Releases provider is **not verified**. macOS: "The macOS updater requires a signed `DesktopUpdaterInstallHelper` inside your app bundle" and "Production builds need Developer ID signing, hardened runtime, and notarization." Ad-hoc builds use a separate development policy. Ships its own `DesktopUpdateWidget`; whether it uses Material is **not verified**, so assume a wrapper.
- Cost: free software; macOS production path needs the paid Apple programme.
- Lock-in: high. Own feed format, own key files, a native helper per platform.
- Remaining glue: about 150 to 250 lines plus CI publish steps and key custody.
- Verdict: the right tool for in-place desktop updates later. Too heavy for a first notice.

### Candidate: upgrader (larryaasen)
- Source URLs: https://pub.dev/api/packages/upgrader ; https://raw.githubusercontent.com/larryaasen/upgrader/main/README.md
- Version and date: 14.0.0, published 2026-11-14. Licence MIT. 76 open issues, last push 2026-11-14, 283,477 downloads in 30 days.
- Platforms: all six tags.
- Rule-out: "A Flutter package for prompting users to upgrade when there is a newer version of the app in the store." "This package relies on scraping public Play Store pages for Android." Widgets "are built with the standalone material_ui and cupertino_ui packages", "UPDATE NOW button takes the user to the App Store (iOS) or Google Play Store (Android)". Appcast mode exists but there is no download, no checksum and the UI is Material. Fails the "no Material in app UI" rule and has no verification.
- Verdict: do not use.

### Candidate: ota_update (4Q)
- Source URLs: https://pub.dev/api/packages/ota_update ; https://raw.githubusercontent.com/4Q-s-r-o/ota_update/master/README.md
- Version and date: 7.1.0, published 2025-12-03. Licence MIT. 26,988 downloads in 30 days, 336 likes. Repository push date and open issues: not verified (search did not return the repository).
- Platform: Android only (tag `platform:android`).
- Behaviour: "On Android it downloads the file (with progress reporting) and triggers app installation intent." Optional `sha256checksum`: "plugin will compute sha256" of the download and report `CHECKSUM_ERROR` on mismatch. Manifest needs `REQUEST_INSTALL_PACKAGES`, `WRITE_EXTERNAL_STORAGE`, a FileProvider and a receiver.
- Remaining glue: about 60 lines Dart plus manifest. Needs our own signature check before we pass it the hash; the plugin's check detects corruption only.
- Verdict: use for the Android install step if the owner accepts the dependency.

### Not chosen, one line each
- `in_app_update` 5.0.0 (MIT, Android only): wraps Google Play in-app updates. README: "cannot be tested locally. It must be installed via Google Play to work." Useless for sideloads. https://raw.githubusercontent.com/jonasbark/flutter_in_app_update/master/README.md
- `velopack_flutter` 0.3.3 (MIT, windows, linux, macos tags; 8 likes, 3,113 downloads in 30 days; GigaDroid, last push 2026-10-19). Wraps Velopack (MIT, last push 2026-11-16, 59 open issues, "Windows, OSX, and Linux"). Needs Rust and flutter_rust_bridge; app must be packed with `vpk` ("API functions will only function correctly in a vpk packed release"). Velopack's own signing page: "On OSX, codesigning and Notarization is required before your application can be run by users." Whether Velopack can read GitHub Releases: **not verified** (docs blocked). Small community. https://raw.githubusercontent.com/GigaDroid/velopack_flutter/master/README.md ; https://raw.githubusercontent.com/velopack/velopack.docs/master/docs/packaging/signing.mdx
- `shorebird_code_push` 2.0.7: patches Dart code in place. Cost and terms **not verified**; and Apple 2.5.2 limits code download. Not examined further.
- `sigstore` 0.2.4 (Dart): `is:unlisted`, `license:unknown`, 298 downloads in 30 days. Not usable. https://pub.dev/api/packages/sigstore
- AppImage plus AppImageUpdate (MIT, last push 2026-10-30, 87 open issues): README says "This is beta-level code." Spec has a `gh-releases-zsync|user|repo|latest|file.zsync` update-information form that "MUST" keep files on GitHub Releases; "pre-releases are not being considered when using `latest`"; a signature section `.sha256_sig` is optional ("MAY embed"). Linux only. Flutter does not produce AppImages by itself (not verified). https://raw.githubusercontent.com/AppImageCommunity/AppImageUpdate/main/README.md ; https://raw.githubusercontent.com/AppImage/AppImageSpec/master/draft.md
- Flatpak and Flathub: Flathub is the "large centralized repository" and updates then come from the user's software centre (https://raw.githubusercontent.com/flatpak/flatpak-docs/master/docs/publishing.rst). Flathub requirements fetched: "Open source and source-available projects must follow established conventions", and "AI tools or agents must not open or automate Flathub submission pull requests" (https://raw.githubusercontent.com/flathub-infra/documentation/main/docs/02-for-app-authors/02-requirements.md). Cost of listing: not verified. A good Linux endgame, a poor first step.
- MSIX with `.appinstaller`: `msix` 3.18.0 (MIT, Windows only, 347,808 downloads in 30 days). Microsoft: "A CA-trusted code signing certificate is required — users cannot install unsigned or self-signed MSIX packages without trusting the cert manually"; Azure Artifact Signing "(~$10/month)"; OV certificates "typically $150-300/year". "The `ms-appinstaller:` URI protocol ... is disabled by default since December 2023". The Store route: "Free (Store re-signs your package)", "no registration fees" for developer accounts. Sources: https://raw.githubusercontent.com/MicrosoftDocs/windows-dev-docs/main/hub/apps/package-and-deploy/choose-distribution-path.md ; .../hub/apps/publish/partner-center/open-a-developer-account.md ; https://pub.dev/packages/msix

## 3. GitHub as the update source

| Fact | Quote | Source |
|---|---|---|
| `releases/latest` meaning | "The latest release is the most recent non-prerelease, non-draft release, sorted by the created_at attribute." | https://docs.github.com/en/rest/releases/releases |
| Unauthenticated rate limit | "The primary rate limit for unauthenticated requests is 60 requests per hour." Counted per originating IP. | https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api |
| Asset digest | The asset object in the docs example has `"digest": "sha256:2151b604..."`. The page does not say who computes it. It would match any file uploaded by someone with write access, so it detects corruption, not a hostile upload. | https://docs.github.com/en/rest/releases/assets |
| Immutable releases | "Release assets cannot be modified or deleted" and tags cannot move after publication; a release attestation is generated automatically. Publish as draft, attach assets, then publish. | https://docs.github.com/en/code-security/supply-chain-security/understanding-your-software-supply-chain/immutable-releases |
| Attestations | `actions/attest-build-provenance` v4 "is simply a wrapper on top of actions/attest"; "new implementations should use `actions/attest` instead". Free for public repositories. Checked with `gh attestation verify PATH -R ORG/REPO`; offline check needs a downloaded bundle and trusted roots. No maintained Dart verifier found (`sigstore` is unlisted with unknown licence). So a client cannot check attestations in-app today. | https://github.com/actions/attest-build-provenance ; https://docs.github.com/en/actions/security-for-github-actions/using-artifact-attestations/using-artifact-attestations-to-establish-provenance-for-builds ; .../verifying-attestations-offline |

**Repository pitfall.** `.github/release-please-config.json` defines two packages with `include-component-in-tag: true` (`lectale` and `edge-api`), so tags look like `lectale-v0.2.0` and `edge-api-v0.2.0` in one repository. `releases/latest` can therefore return an `edge-api` release. The client must list releases and pick the newest whose `tag_name` starts with `lectale-v`. I could not call the live repository API (repository endpoints are refused for repos not attached to this session), so the release shape is **not verified live**. Also, release-please must create GitHub Releases and the build assets must be attached to them; today CI only keeps seven-day workflow artifacts (`retention-days: 7`), and nothing attaches assets to a release.

## 4. Signing and cost per platform

| Platform | Finding | Source |
|---|---|---|
| Android | Stable release keystore, free to create, valid at least 25 years ("Your key should be valid for at least 25 years"). Losing it means no more updates for that package. Developer verification may add $25 from 2027 (section 1). | https://developer.android.com/studio/publish/app-signing |
| macOS | Developer ID certificate: "you must be the Account Holder of your development team in the Apple Developer Program". Notarization appears in the compare-memberships table with no tick in the "Registered for free" column and ticks for Program and Enterprise. Programme: "$99 annual membership". Flutter docs: "You need to notarize your macOS application before distributing it outside the macOS App Store." What an unsigned or ad-hoc app does under Gatekeeper on a current macOS: **not verified** (support.apple.com blocked). Apple's Developer ID page says Gatekeeper checks "for a Developer ID certificate from apps distributed outside the Mac App Store". Test on a real Mac before promising anything. | https://developer.apple.com/developer-id/ ; https://developer.apple.com/support/compare-memberships/ ; https://developer.apple.com/programs/ ; https://docs.flutter.dev/platform-integration/macos/building |
| Windows | No signature: "Warning — 'Windows protected your PC'; User must choose 'Run anyway'". Self-signed behaves the same. "When a file is not signed, SmartScreen reputation must build for each new version." A signed file also warns until reputation builds, and "EV certificates no longer bypass SmartScreen". Azure Artifact Signing from "$9.99/month". Microsoft Store: no SmartScreen warning, Store signs, "no registration fees". | https://raw.githubusercontent.com/MicrosoftDocs/windows-dev-docs/main/hub/apps/package-and-deploy/smartscreen-reputation.md |
| Linux | No signing system or store needed for a tarball. | not applicable |
| iOS | Free Apple account, "Personal Team": "up to 3 devices, which expire after 7 days", "up to 3 apps per device", provisioning profiles "expire 7 days from issuance". TestFlight and App Store Connect are Program-only ($99). So there is no practical download-and-install for the public without the paid programme. | https://developer.apple.com/support/compare-memberships/ |

## 5. Web

- `flutter build web` writes `version.json` with the app version and build number (Flutter 3.50.1 source: `createVersionFile` writes `version.json` from `version` and `build_number`). https://raw.githubusercontent.com/flutter/flutter/3.50.1/packages/flutter_tools/lib/src/build_system/targets/web.dart
- Flutter no longer ships a caching service worker: "Flutter no longer generates or manages a caching service worker by default (in newer versions, it writes a self-cleaning stub to remove legacy service workers)." So there is no service worker "update available" event to hook. https://docs.flutter.dev/platform-integration/web/faq
- `--web-content-hash` (3.50 and later) puts a hash in entrypoint and asset file names; "You still need to serve index.html and flutter_bootstrap.js with revalidation". https://docs.flutter.dev/platform-integration/web/faq
- Workers static assets already send `Cache-Control: public, max-age=0, must-revalidate` with an ETag, and a `_headers` file can override it, so a plain fetch of `/version.json` returns the deployed version. https://developers.cloudflare.com/workers/static-assets/headers/index.md Caveat from the same page: `_headers` rules do not apply to responses the Worker itself generates (`run_worker_first`), which matters only if `/version.json` is routed through the Worker.
- Design: compile the running version in (`--dart-define` from `pubspec.yaml`, or `package_info_plus` 10.2.2, BSD-3, all six platforms), fetch `/version.json` with `cache: no-store` on start and on tab focus, compare with `pub_semver` (2.2.1, BSD-3) and show "Reload for the new version" calling `location.reload()`.

## 6. Per-platform table

Effort is lines of our own code (Dart unless stated), my estimate. Difficulty S, M, L, XL is for the "now" column.

| Platform | What is allowed | Recommended mechanism now | Package or tool | Verification | Cost | Effort (lines) | Difficulty now |
|---|---|---|---|---|---|---|---|
| Web | Reload; no install | Compare `/version.json` to the running build; offer "Reload" | none (`package_info_plus` or a `--dart-define`, `pub_semver`) | Same-origin HTTPS, Worker serves it | 0 | 50 | S |
| Android | Sideload with user confirmation, `REQUEST_INSTALL_PACKAGES`, same signing key; 2027 developer-verification rules | Notice, then download the APK, verify, hand to the system installer | `ota_update` (MIT) with `sha256checksum`, own Ed25519 check first | Signed `SHA256SUMS` plus APK hash; Android checks the signing key itself | 0 now; $25 if full verification is needed in 2027; Play fee not verified | 60 plus manifest and a stable release keystore in CI | M |
| iOS | No install without signing; 2.5.2 limits code download | Notice only, link to the release page | `url_launcher` (BSD-3) | not applicable | $99/yr for TestFlight or store | 10 | S |
| Linux | Anything; user replaces the folder | Notice, download the `.tar.gz`, verify, open the folder | `dio` (in use), `crypto`, `cryptography`, `url_launcher` | Signed `SHA256SUMS` | 0 | 80 | S |
| Windows | Unsigned `.zip` runs after a SmartScreen "Run anyway" | Notice, download the `.zip`, verify, open the folder | same as Linux | Signed `SHA256SUMS` | 0 now; signing from $9.99 a month, or Store (free signing) | 80 | S |
| macOS | Unsigned app needs the user to override Gatekeeper (behaviour not verified) | Notice, download the `.tar.gz`, verify, open the folder | same as Linux | Signed `SHA256SUMS` | 0 now; $99/yr for Developer ID and notarization | 80 | S, with a manual Mac test |

Shared code (about 250 lines): release lookup, tag filter, semver compare, signature and hash check, cache of the last check, one notice banner in `devchat_ui`. About 80 lines of YAML for the release job.

Later, with certificates or stores:

| Platform | Later mechanism | Needs | Difficulty |
|---|---|---|---|
| Windows | `desktop_updater` or `auto_updater` in-place update, or Store | Code-signing ($9.99 a month) or free Store account | L |
| macOS | `desktop_updater` or `auto_updater` (Sparkle) | Apple Developer Program ($99/yr), Developer ID, notarization | L |
| Linux | `desktop_updater`, or Flathub listing | Key custody; Flathub review | M |
| Android | Play Store listing, or keep sideload | Play account (fee not verified), $25 verification for sideloading from 2027 | M |
| iOS | TestFlight and App Store | $99/yr; no self-updating | XL |

## 7. Verification design

Digest from the release API only catches corruption. A hostile upload by anyone with release write access would carry a matching digest. So:

1. The release job produces `SHA256SUMS` (one line per asset) and `SHA256SUMS.sig`, an Ed25519 signature made with a release key the owner controls.
2. The app has the public key compiled in. It downloads both small files, checks the signature, finds the line for its asset, downloads the asset, checks the SHA-256, and only then shows "Download" as complete or hands the APK to the installer.
3. Libraries: `crypto` 3.0.8 (BSD-3) for SHA-256; `cryptography` 2.9.0 (Apache-2.0, six platform tags) or `ed25519_edwards` 0.3.2 (Apache-2.0, six platform tags) for Ed25519. I did not read their APIs or test that Ed25519 verification works on all six; confirm in the first task.
4. Turn on immutable releases and add `actions/attest` so people can run `gh attestation verify`. This is a human check, not a client check.
5. Key custody is the owner's decision: a secret in a protected GitHub environment is simplest; signing by hand at release time keeps the key off CI. Losing or leaking the key means shipping a new public key in an app update, so keep a backup.

Threats not covered: an attacker who has both release write access and the signing key; a compromised app build (the pinned key is only as trustworthy as the build that embeds it); rollback to an older signed release (the client must only offer a version greater than its own).

## 8. Recommendation

**Build own, no new paid service.** No ready-made package gives a GitHub-release check, a signature check and a litse-ui notice on six platforms. `desktop_updater` is the closest, but it needs its own feed, a macOS helper and Developer ID. `upgrader` is store-oriented and Material.

Build now: the shared lookup and verification code, a `devchat_ui` banner, web reload, and download-and-verify for Linux, Windows, macOS and Android; iOS gets a link. Self-replacing desktop installs come after signing exists.

The shared code is about 250 lines and the whole feature is about 500 with platform glue. The intake gate says to look for a library above 200 lines, so the ADR carries the exception.

ADR exception text: "No maintained package checks GitHub Releases, verifies a pinned Ed25519 signature, and renders in litse-ui on six platforms. `upgrader` scrapes stores and uses Material, `auto_updater` has no Linux, no mobile, and `desktop_updater` needs a macOS helper and Developer ID. We write about 250 shared lines on top of `dio`, `crypto`, `cryptography`, `pub_semver`, `package_info_plus` and `url_launcher`, plus `ota_update` for Android."

Needs owner decision before building:
- Approve `ota_update`, `cryptography` (or `ed25519_edwards`), `pub_semver`, `crypto`, `package_info_plus`, `url_launcher` as dependencies (AGENTS.md asks first).
- Choose where the release signing key lives.
- Decide when to create the Android release keystore and whether to pay $25 for Android developer registration.
- Whether and when to pay for: Apple Developer Program ($99/yr), Windows signing (from $9.99/month) or open a free Microsoft Store account, Play registration (fee not verified).

Not verified: Google Play self-update policy; Gatekeeper behaviour for unsigned macOS apps; the Android error for a mismatched signing key; live shape of this repository's releases and asset names; whether `desktop_updater` or Velopack can read GitHub Releases; Flathub listing cost; licences of Sparkle and WinSparkle; the Android limited-distribution device cap (20 or 50, two pages disagree).
