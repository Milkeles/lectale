# Runbook: create the release signing keys

Two keys protect every update Lectale ships (ADR-0013). The owner creates them on their own computer, so no agent session ever holds them. The commands were tested on 2026-11-21 with OpenSSL 3.0 and the JDK's `keytool`, using throwaway keys.

| Key | Protects | If it is lost | If it leaks |
|---|---|---|---|
| Update signing key (Ed25519) | The signed `SHA256SUMS` on each release; the app refuses downloads that don't match it | New releases can't be verified until an app update ships a new public key | Anyone could sign a fake release: make a new key, ship its public key in an update, and delete the old secret |
| Android release key | The APK signature; Android only installs an update signed with the same key | Existing installs can't update in place; users must uninstall first | Anyone could publish an APK Android accepts as an update |

## When to do this

Once, before the first release that the update notice should see. Keep both private files and the password in your password manager. They can't be recovered from GitHub.

## Steps

1. In a terminal, make an empty folder and go into it. On Windows, use Git Bash, which includes OpenSSL.

2. Create the update signing key and print its public half:

   ```bash
   openssl genpkey -algorithm ed25519 -out lectale-update-key.pem
   openssl pkey -in lectale-update-key.pem -pubout -outform DER | tail -c 32 | base64
   ```

   The second command prints one line ending in `=`. That's the public key. It's safe to share: paste it into the chat, and an agent compiles it into the app.

3. Create the Android release key. `keytool` comes with Java; Android Studio bundles one (on Linux, `~/android-studio/jbr/bin/keytool`). Choose a long password when asked:

   ```bash
   keytool -genkeypair -keystore lectale-release.p12 -storetype PKCS12 \
     -keyalg RSA -keysize 4096 -validity 10000 -alias lectale -dname "CN=Lectale"
   base64 -w0 lectale-release.p12 > lectale-release.p12.b64
   ```

   On macOS, use `base64 -i lectale-release.p12 -o lectale-release.p12.b64` for the second line.

4. In GitHub, go to `Milkeles/lectale` → **Settings → Environments → New environment** and name it `release`. Under **Deployment branches and tags**, choose **Selected branches and tags** and add the tag pattern `lectale-v*`, so only release tags can use these secrets. Then add three environment secrets:

   | Secret | Value |
   |---|---|
   | `UPDATE_SIGNING_KEY` | the whole contents of `lectale-update-key.pem`, including the BEGIN and END lines |
   | `ANDROID_KEYSTORE_BASE64` | the contents of `lectale-release.p12.b64` |
   | `ANDROID_KEYSTORE_PASSWORD` | the password from step 3 |

5. Save `lectale-update-key.pem`, `lectale-release.p12` and the password in your password manager. Then delete the folder.

## How the release job uses them

When release-please tags a `lectale-v*` release, the release job runs in the `release` environment. It builds each platform, signs the Android APK with the release key, writes `SHA256SUMS`, and signs that file with the update key (`openssl pkeyutl -sign -rawin`). Then it attaches everything to the GitHub release. The app checks the signature with the public key from step 2 before it offers any download.

## To replace a key

- **Update key:** do step 2 again and replace the secret. Ship an app release that carries the new public key, then the next release is signed with the new key.
- **Android key:** existing installs can't take updates signed with a new key. Avoid this; if it happens, users uninstall and install again.
