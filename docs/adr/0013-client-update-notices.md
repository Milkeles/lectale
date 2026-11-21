---
status: accepted
date: 2026-11-21
---

# Client update notices from GitHub releases, verified before download

## Context and problem statement

Releases are cut when a milestone closes (release-please, tags such as
`lectale-v0.2.0`). Installed clients have no way to learn that a newer
version exists. The owner wants a notice and a download of the right file
for the platform.

An update channel is a supply-chain risk (threat model row 7.3). A binary
must be verified before it is offered or installed. There is no Apple
Developer Program membership, no Google Play listing and no Windows
signing certificate, and each costs money. The facts behind this record are
in [the research note](../research/2026-11-21-client-updates.md).

Three findings shape the decision:

- GitHub's asset `digest` only detects corruption. Anyone who can upload an
  asset can also produce a matching digest.
- No Dart package verifies GitHub artifact attestations (`sigstore` is
  unlisted and has no licence).
- The repository holds two release-please components, so `releases/latest`
  can return an `edge-api` release instead of a `lectale` one.

## Decision drivers

- Threat model row 7.3: no unverified binary offered or installed.
- No new recurring cost and no account creation without the owner.
- Six platforms; app UI uses litse-ui, not Material.
- The Apple App Review rule 2.5.2 forbids downloading code that changes app
  features, so iOS gets a link only.
- Android installs need `REQUEST_INSTALL_PACKAGES`, the same signing key
  across versions, and a user confirmation.

## Considered options

- Notice plus verified download from GitHub Releases, written by us (about
  500 lines in total).
- `desktop_updater` for desktop plus `ota_update` for Android: in-place
  updates, but a separate feed, a macOS helper that needs Developer ID and
  notarization, and no web or iOS.
- `upgrader`: store-oriented, built on Material, no verification.
- `auto_updater` (Sparkle and WinSparkle): Windows and macOS only.
- Velopack through `velopack_flutter`: needs Rust and `vpk` packaging;
  GitHub Releases support not verified.
- Store distribution first (Play, App Store, Microsoft Store, Flathub):
  updates come from the store, but they cost money or need accounts.

## Decision outcome

Chosen option: "notice plus verified download, written by us", because it
is the only one that works on all six platforms at no cost and can meet the
verification rule.

- **Source:** the client lists GitHub releases and takes the newest
  non-draft, non-prerelease whose tag starts with `lectale-v`. It never
  uses `releases/latest`. It checks at most every 12 hours and on start, to
  stay under 60 unauthenticated requests an hour per IP.
- **Release assets:** the release job attaches one file per platform with a
  fixed name, `SHA256SUMS` and `SHA256SUMS.sig`. The signature is Ed25519.
  The public key is compiled into the app. Immutable releases are on and
  `actions/attest` records provenance for people to check with
  `gh attestation verify`.
- **Client check:** verify the signature, find the asset's line, download the
  asset, compare SHA-256, and only then show it as ready. Offer only a
  version greater than the running one.
- **Platforms:**
  - Web compares `/version.json` with the running build and offers
    "Reload".
  - Linux, Windows and macOS download, verify and open the folder. The user
    replaces the app. No self-replacing install until signing exists.
  - Android downloads, verifies and hands the APK to the system installer
    with `ota_update`. This needs a stable release keystore in CI.
  - iOS shows the notice and links to the release page.
- **Owner decisions (2026-11-21):** the owner approved the dependencies
  (`ota_update`, `cryptography`, `crypto`, `pub_semver`, `package_info_plus`,
  `url_launcher`). The owner creates both signing keys on their own computer
  and stores them in the GitHub environment `release`
  (`docs/runbooks/release-signing-keys.md`). Releases are distributed on
  GitHub only; no paid developer accounts for now.

Exception to the 200-line rule: no maintained package checks GitHub
Releases, verifies a pinned Ed25519 signature and renders in litse-ui on
six platforms. About 250 shared lines are ours, on top of ready-made
packages for hashing, signatures, downloads and the Android install.

### Consequences

- Good, because it costs nothing and needs no store account.
- Good, because a hostile upload alone cannot pass the client check.
- Good, because later signing and stores layer on top: `desktop_updater` for
  in-place desktop installs, store updates for mobile.
- Bad, because desktop users replace the app by hand.
- Bad, because the signing key is a new secret to guard and back up. A
  leaked key needs a new public key shipped in an app update.
- Bad, because unsigned Windows and macOS downloads still meet SmartScreen
  and Gatekeeper. Certificates cost money: Windows from $9.99 a month, Apple
  $99 a year.
- Bad, because Android sideloads may need developer registration from 2027
  ($25 for a full account).

### Confirmation

- Unit tests: tag filter ignores `edge-api-v*`, prereleases and drafts;
  an older or equal version is not offered; a changed asset byte, a changed
  `SHA256SUMS` line and a wrong signature each fail.
- A CI step that runs the client verifier against the just-built release
  files before the release is published.
- Security review and a Codex review of the verifier and the release
  workflow, because they are security-sensitive.
- Manual pass: install an unsigned build on a Mac, a Windows machine and an
  Android phone, take the update, and record what the system warns about.

## More information

- [Research note](../research/2026-11-21-client-updates.md): sources,
  platform rules, candidate packages and what is not verified.
- Revisit when the owner buys a certificate or opens a store listing, and
  before 2027 (Android developer verification expands globally).
- Not verified yet: Google Play's self-update policy, Gatekeeper behaviour
  for unsigned apps, and the live shape of this repository's releases.
