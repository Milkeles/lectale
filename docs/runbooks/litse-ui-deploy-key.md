# Runbook: give CI read access to litse-ui

Lectale depends on `devchat_ui` from the private repository `Milkeles/litse-ui-private` (ADR-0004). GitHub Actions in `Milkeles/lectale` can fetch it only with a deploy key. Without the key, the Flutter jobs are skipped and say so in the job log.

## When to do this

Once, before Flutter CI is expected to pass. Repeat if the key is ever exposed.

## Steps

1. On your own machine, create a key pair with no passphrase:

   ```bash
   ssh-keygen -t ed25519 -C lectale-ci -N "" -f lectale_ci
   ```

2. In `Milkeles/litse-ui-private`, go to **Settings → Deploy keys → Add deploy key**. Name it `lectale-ci` and paste the contents of `lectale_ci.pub`. Leave **Allow write access** off.
3. In `Milkeles/lectale`, go to **Settings → Secrets and variables → Actions → New repository secret**. Name it `LITSE_UI_DEPLOY_KEY` and paste the contents of `lectale_ci`, the private half.
4. Delete both files from your machine.

## How CI uses it

The Flutter jobs start `ssh-agent` with the secret and run `flutter pub get`. Pub then clones `git@github.com:Milkeles/litse-ui-private.git` at the pinned tag. The key can read that one repository and nothing else. Pull requests from forks don't receive secrets, so they run only the TypeScript and contract jobs.

## To revoke

Delete the deploy key in litse-ui-private's settings and the secret in lectale's settings. Then create a new key as above.
