const ALLOWED_HOSTS = new Set(["api.github.com", "raw.githubusercontent.com"]);
const REDIRECTS = new Set([301, 302, 303, 307, 308]);
const MAX_REDIRECTS = 3;
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
  options: { token?: string; range?: string } = {},
): Promise<Response> {
  let url = new URL(address);
  checkUrl(url);
  const headers = new Headers({ "User-Agent": "Lectale" });
  if (url.hostname === "api.github.com") {
    headers.set("Accept", "application/vnd.github+json");
    if (options.token) headers.set("Authorization", `Bearer ${options.token}`);
  } else {
    headers.set("Accept-Encoding", "identity");
    if (options.range !== undefined) headers.set("Range", options.range);
  }

  const signal = AbortSignal.timeout(TIMEOUT_MS);
  for (let redirects = 0; ; redirects++) {
    const response = await fetch(url, { headers, redirect: "manual", cache: "no-store", signal });
    if (!REDIRECTS.has(response.status)) return response;
    const location = response.headers.get("Location");
    void response.body?.cancel().catch(() => undefined);
    if (!location || redirects === MAX_REDIRECTS) {
      throw new Error("GitHub redirect could not be followed.");
    }
    const destination = new URL(location, url);
    checkUrl(destination);
    if (destination.origin !== url.origin) {
      throw new Error("Cross-host GitHub redirects are forbidden.");
    }
    url = destination;
  }
}
