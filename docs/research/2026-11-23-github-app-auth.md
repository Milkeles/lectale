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

GitHub documents that an installation token can be granted access only within
the installation and that public repository metadata can be read without
credentials. Whether the public REST reads succeed with an installation token
outside its installation is still unverified. The Worker retries anonymously
once on credential or scope denials, while honoring rate limits; when that
retry is itself rate-limited it pauses and answers a retryable 429. The deploy
workflow's key check prints whether the scoped token reads
`octocat/Hello-World`, which settles this on the first deployment.
[Installation token scope](https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-an-installation-access-token-for-a-github-app),
[Get a repository](https://docs.github.com/en/rest/repos/repos#get-a-repository)

The shell proxy refused the requested curl connections, and direct curl could
not resolve `docs.github.com`. The excerpts above were checked against the
official pages through the browser tool.
