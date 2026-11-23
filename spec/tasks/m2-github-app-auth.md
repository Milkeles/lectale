# Task: the Worker reads GitHub with the Lectale GitHub App's token

| Intake | |
|---|---|
| **Why** | Anonymous GitHub API calls allow 60 requests an hour per IP, and every visitor shares the Worker's egress, so the public preview (V4-CORE-01) runs dry quickly. A GitHub App installation token allows at least 5,000 an hour. The owner created the App (Contents read and write, Metadata read) and stored its ID and private key, PKCS#8, as the repository secrets `GH_APP_ID` and `GH_APP_PRIVATE_KEY`. This is spike S2 plus its implementation. |
| **Simpler** | Mint the App JWT with WebCrypto (RS256, PKCS#8 import). Exchange it for an installation token for the owner's installation. Cache the token in memory per isolate until 5 minutes before it expires. Send it on the existing GitHub reads. No new route except a health detail. No user-to-server tokens yet (M4). |
| **Ready-made** | WebCrypto is built into Workers. `jose` is in the research ledger as Workers-compatible, but WebCrypto alone is enough for one RS256 signature; prefer no new dependency and explain the choice. Check against GitHub's docs, fetched with curl from docs.github.com: generating a JWT for a GitHub App, generating an installation access token, and the rate limits for GitHub Apps. Quote what you rely on in a short note at `docs/research/2026-11-23-github-app-auth.md`. |
| **Security** | Trust boundary: the private key and the installation token.<br>- Both live only in Worker secrets (`env.GH_APP_ID`, `env.GH_APP_PRIVATE_KEY`).<br>- Neither is ever logged, returned, cached in the Cache API or written to D1.<br>- The token only ever goes to `api.github.com`, never to `raw.githubusercontent.com` (public raw reads stay anonymous) and never to any other host (WORKER_FETCH_HOSTS).<br>- If the secrets are missing or token minting fails, the Worker falls back to anonymous reads and logs one redacted warning; it never sends a broken Authorization header.<br>- A security review (Claude) and a Codex review are needed before merge. |
| **Verify** | `cd apps/edge_api && npm test` passes, including new tests:<br>- JWT claims (`iat` 60 s in the past, `exp` at most 10 min, `iss` the App ID) and a signature that verifies with the public key, using a test key pair generated in the test;<br>- token caching and refresh;<br>- the Authorization header goes only to api.github.com;<br>- the anonymous fallback;<br>- no secret appears in any response or log line.<br>`npm run typecheck` passes. `python3 tool/check_rules.py` passes. |

## Build

1. **`apps/edge_api/src/github/app-auth.ts`.** Import the PKCS#8 PEM, sign the JWT, find the installation, exchange it for a token and cache it. Finding the installation: `GET /app/installations`, choosing the one whose account is the App owner. Make the account login a non-secret var `GH_APP_INSTALLATION_ACCOUNT` (default `Milkeles`) in `wrangler.jsonc`. Wire it into `github/rest-reader.ts` through the existing `net/fetch.ts`.
2. **Health detail.** `GET /api/health` gains `github: { auth: "app" | "anonymous" }`. Never include limits or secrets beyond that word.
3. **Deploy.** In `.github/workflows/deploy-preview.yml`, after `wrangler deploy`, upload both secrets with `npx wrangler secret bulk`. Build its JSON input from environment variables with Node (`JSON.stringify` on `process.env`), so the PEM's newlines survive and nothing is echoed. Read the secrets from `${{ secrets.GH_APP_ID }}` and `${{ secrets.GH_APP_PRIVATE_KEY }}`. Run `zizmor --offline` on the workflow.
4. **Post-deploy check.** The same workflow ends with a step that fetches `https://lectale.fervorgames.workers.dev/api/health` and fails if `github.auth` isn't `app`.

## Unknown, to record after the first deploy

Whether an installation token can read public repositories that aren't in the installation. GitHub's docs are ambiguous. If it can't, the fallback still serves those repositories anonymously; note this in the research note.

Commit nothing.
