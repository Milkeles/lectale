# Task: release workflow with signed checksums

| Intake | |
|---|---|
| **Why** | ADR-0013: installed clients learn about new versions from GitHub releases and must verify a download before offering it (threat model row 7.3). The release job has to produce the files the client checks. The owner is creating the keys (`docs/runbooks/release-signing-keys.md`). |
| **Simpler** | One workflow that runs when release-please creates a `lectale-v*` tag. It does four things: builds each platform, signs the Android APK, writes `SHA256SUMS` and signs it with Ed25519, and attaches everything to that release. **Not building:** the in-app notice (a separate Flutter task), store uploads, code signing for Windows or macOS (no certificates), in-place desktop updates. |
| **Ready-made** | OpenSSL on the runner for Ed25519 (`openssl pkeyutl -sign -rawin`), Android's `apksigner` from the SDK on the runner, `actions/attest-build-provenance` for provenance, and the existing per-platform build jobs in `.github/workflows/ci.yml` as the template. No new dependency in the app. |
| **Security** | **Trust boundary:** the signing keys and what gets published.<br>- The job runs in the GitHub environment `release`, which only `lectale-v*` tags can use, with secrets `UPDATE_SIGNING_KEY`, `ANDROID_KEYSTORE_BASE64` and `ANDROID_KEYSTORE_PASSWORD`. Least privilege: `contents: write` only on the job that uploads, plus `id-token: write` and `attestations: write` on the attest step.<br>- Keys are written to files with mode 600 in `$RUNNER_TEMP` and deleted in an `always()` step. Nothing echoes a secret.<br>- Every action is pinned by SHA, and `zizmor --offline` is clean.<br>- Before upload, the job verifies its own output: it checks `SHA256SUMS.sig` against the public key and every asset's hash against `SHA256SUMS`.<br>- It never uses `releases/latest` or touches `edge-api` releases.<br>- A Claude security review and a Codex review are needed before merge. |
| **Verify** | `zizmor --offline` on the new workflow reports nothing.<br>A local script `tool/release/sign-and-verify.sh`, which the workflow also uses:<br>- run with throwaway keys made in a temp folder, it produces `SHA256SUMS` and `SHA256SUMS.sig` for sample files;<br>- it verifies them;<br>- it fails when one byte of an asset changes, when one line of `SHA256SUMS` changes, or when the signature comes from another key.<br>Its test, `tool/release/test.sh`, covers those four cases and passes. |

## Build

1. `.github/workflows/release.yml`:
   - **Trigger:** `release: published` for tags `lectale-v*`, or a `workflow_call` from release-please's workflow. Check how release-please is wired in `.github/workflows/` and pick the one that runs after the tag exists.
   - **Builds:** reuse the CI build steps for Android (signed release APK), Linux (tar.gz), Windows (zip), macOS (tar.gz) and web (zip).
   - **Asset names:** fixed: `lectale-android.apk`, `lectale-linux-x64.tar.gz`, `lectale-windows-x64.zip`, `lectale-macos.tar.gz`, `lectale-web.zip`. `/download/android` already redirects to `releases/latest/download/lectale-android.apk`, so keep that name.
   - **Signing:** write `SHA256SUMS` in `sha256sum` format, then sign it with the Ed25519 key, raw signature, base64, into `SHA256SUMS.sig`.
   - **Before upload:** verify with the script, then attest.
   - **Upload:** attach everything to the triggering release.
2. `tool/release/sign-and-verify.sh` and `tool/release/test.sh` as above. POSIX shell plus OpenSSL 3, with no other tools.
3. Update `docs/runbooks/release-signing-keys.md` if anything in "How the release job uses them" changes.

## Boundaries

Work in your own worktree. Don't push, tag, create releases or touch real secrets. Don't edit `ci.yml` beyond extracting shared steps if that clearly reduces duplication; if you do, explain why. Report the files changed, the Verify output, and anything you couldn't test, such as steps that need real runners.
