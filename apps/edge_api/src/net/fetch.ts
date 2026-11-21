const ALLOWED_HOSTS = new Set(["api.github.com", "raw.githubusercontent.com"]);
const REDIRECTS = new Set([301, 302, 303, 307, 308]);
const TIMEOUT_MS = 30_000;

function checkUrl(url: URL): void {
  if (url.protocol !== "https:" || url.username || url.password || url.port
      || !ALLOWED_HOSTS.has(url.hostname)) {
    throw new Error("Outbound URL is outside the GitHub HTTPS allowlist.");
  }
}

/**
 * Makes a bounded GitHub GET (V4-SEC-03). Headers are constructed here so
 * client credentials cannot cross the boundary. The optional token comes
 * from the server and is sent only to the REST API.
 */
export async function fetchGitHub(
  address: string | URL,
  options: { token?: string; range?: string; accept?: string; repositoryRedirect?: boolean } = {},
): Promise<Response> {
  let url = new URL(address);
  checkUrl(url);
  const headers = new Headers({ "User-Agent": "Lectale" });
  if (url.hostname === "api.github.com") {
    headers.set("Accept", options.accept ?? "application/vnd.github+json");
    if (options.token) headers.set("Authorization", `Bearer ${options.token}`);
  } else {
    headers.set("Accept-Encoding", "identity");
    if (options.range !== undefined) headers.set("Range", options.range);
  }

  const signal = AbortSignal.timeout(TIMEOUT_MS);
  const init: RequestInit = { headers, redirect: "manual", cache: "no-store", signal };
  const response = await fetch(url, init);
  if (!REDIRECTS.has(response.status)) return response;
  const location = response.headers.get("Location");
  void response.body?.cancel().catch(() => undefined);
  if (!location || !options.repositoryRedirect || url.hostname !== "api.github.com"
      || !/^\/repos\/[^/]+\/[^/]+$/u.test(url.pathname)) {
    throw new Error("Unexpected GitHub redirect.");
  }
  const destination = new URL(location, url);
  checkUrl(destination);
  if (destination.origin !== url.origin || !/^\/repositories\/[1-9][0-9]*$/u.test(destination.pathname)
      || destination.search || destination.hash) {
    throw new Error("Unexpected GitHub repository redirect.");
  }
  // GitHub's name lookup can redirect to the same operation by stable ID.
  url = destination;
  const redirected = await fetch(url, init);
  if (!REDIRECTS.has(redirected.status)) return redirected;
  void redirected.body?.cancel().catch(() => undefined);
  throw new Error("Unexpected GitHub redirect chain.");
}
