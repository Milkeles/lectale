# GitHub App authentication on Workers

Task S2 supports public course previews (V4-CORE-01) and keeps GitHub App
credentials server-side (V4-SEC-04).

- GitHub requires a JWT “signed using the `RS256` algorithm.” It recommends
  setting `iat` “60 seconds in the past,” limits `exp` to “no more than 10
  minutes into the future,” and accepts the App ID for `iss`. The REST request
  sends the JWT as a bearer credential. [Generating a JWT for a GitHub App](https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-a-json-web-token-jwt-for-a-github-app)
- GitHub lists `GET /app/installations` for discovering the installation ID.
  The list endpoint says, “You must use a JWT to access this endpoint.” The
  Worker matches the configured account login, which defaults to `Milkeles`.
  [List installations for the authenticated app](https://docs.github.com/en/rest/apps/apps#list-installations-for-the-authenticated-app)
- GitHub says to “Send a REST API `POST` request to
  `/app/installations/INSTALLATION_ID/access_tokens`” and says the token “will
  expire after 1 hour.” The request narrows the token to Contents and Metadata
  read permissions. The Worker uses the returned expiry to refresh five minutes
  early. [Generating an installation access token](https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-an-installation-access-token-for-a-github-app)
- GitHub distinguishes App user tokens from installation tokens. Its REST
  limits are “60 requests per hour” for anonymous requests per IP and a
  “minimum rate limit of 5,000 requests per hour” per installation.
  [Rate limits for GitHub Apps](https://docs.github.com/en/apps/creating-github-apps/registering-a-github-app/rate-limits-for-github-apps),
  [REST API rate limits](https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api#primary-rate-limit-for-github-app-installations)

WebCrypto imports the supplied PKCS#8 key and produces the one RS256 signature
needed for both App-authenticated REST calls. The existing outbound adapter
handles the HTTP exchange, so this path needs neither `jose` nor Octokit.
Tokens stay in isolate memory, scoped by `repository_ids` to the one public
repository `Milkeles/lectale` (V4-SEC-04). Raw file requests remain anonymous.
`/api/health` stays `{"status":"ok"}` and calls nothing upstream. The deploy
workflow checks the key and the scoped exchange with GitHub before deploying.

## Public repositories outside the installation

Settled on 2026-11-23. The deploy workflow's key check minted a token scoped
by `repository_ids` to `Milkeles/lectale` and read `octocat/Hello-World` with
it: HTTP 200 (log of the "Deploy preview" run 45148228687). A scoped
installation token reads public repositories outside its scope. Its 403 or 404
is therefore GitHub's real answer, the same an anonymous read gets, so the
Worker no longer retries those anonymously. Only a rejected token (401) falls
back to one anonymous read, with its own cooldown.

Confirmed for every read the preview makes on 2026-11-28 ("Deploy preview" run
46154387264): with the scoped token, `octocat/Hello-World` answered HTTP 200
for its metadata, `commits/HEAD` and `contents/`.

[Installation token scope](https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-an-installation-access-token-for-a-github-app),
[Get a repository](https://docs.github.com/en/rest/repos/repos#get-a-repository)
