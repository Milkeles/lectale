import { readBoundedBody } from "../net/bounded-body";
import { fetchGitHub } from "../net/fetch";
import { isRepoId } from "./reader";

const REST = "https://api.github.com";
const PAGE_SIZE = 100;
const MAX_PAGES = 5;
const REFRESH_EARLY_MS = 5 * 60_000;
// GitHub issues one-hour tokens. Capping the reuse window keeps a malformed
// or hostile `expires_at` from pinning a token in memory for longer.
const MAX_REUSE_MS = 55 * 60_000;
const RETRY_MS = 60_000;

/** Server-only GitHub App configuration for public preview reads (V4-SEC-04). */
export interface GitHubAppBindings {
  GH_APP_ID?: string;
  GH_APP_PRIVATE_KEY?: string;
  GH_APP_INSTALLATION_ACCOUNT?: string;
  /** Non-secret ID of the one public repository the token is limited to. */
  GH_APP_TOKEN_REPOSITORY_ID?: string;
}

interface InstallationToken {
  token: string;
  refreshAt: number;
}

function base64Url(bytes: Uint8Array): string {
  return btoa(String.fromCharCode(...bytes)).replaceAll("+", "-").replaceAll("/", "_").replace(/=+$/u, "");
}

async function signJwt(appId: string, pem: string): Promise<string> {
  const match = /^-----BEGIN PRIVATE KEY-----\s+([A-Za-z0-9+/=\s]+)-----END PRIVATE KEY-----$/u.exec(pem.trim());
  if (!match?.[1]) throw new Error("Expected a PKCS#8 private key.");
  const der = Uint8Array.from(atob(match[1].replace(/\s/gu, "")), (character) => character.charCodeAt(0));
  const algorithm = "RSASSA-PKCS1-v1_5";
  const key = await crypto.subtle.importKey("pkcs8", der, { name: algorithm, hash: "SHA-256" }, false, ["sign"]);
  const now = Math.floor(Date.now() / 1_000);
  const encoder = new TextEncoder();
  const header = base64Url(encoder.encode(JSON.stringify({ alg: "RS256", typ: "JWT" })));
  const claims = base64Url(encoder.encode(JSON.stringify({ iat: now - 60, exp: now + 540, iss: appId })));
  const input = `${header}.${claims}`;
  const signature = await crypto.subtle.sign(algorithm, key, encoder.encode(input));
  return `${input}.${base64Url(new Uint8Array(signature))}`;
}

async function authJson(response: Response, status: number): Promise<unknown> {
  if (response.status !== status) {
    void response.body?.cancel().catch(() => undefined);
    throw new Error("GitHub App authentication failed.");
  }
  const bytes = await readBoundedBody(response.body, 512 * 1024);
  if (!bytes) throw new Error("GitHub App response exceeded its byte budget.");
  return JSON.parse(new TextDecoder("utf-8", { fatal: true, ignoreBOM: false }).decode(bytes)) as unknown;
}

async function findInstallation(jwt: string, account: string): Promise<number> {
  for (let page = 1; page <= MAX_PAGES; page += 1) {
    const response = await fetchGitHub(`${REST}/app/installations?per_page=${PAGE_SIZE}&page=${page}`, { token: jwt });
    const payload = await authJson(response, 200);
    if (!Array.isArray(payload)) break;
    for (const item of payload as unknown[]) {
      const installation = item as { id?: unknown; account?: { login?: unknown } | null } | null;
      const login = installation?.account?.login;
      if (typeof login === "string" && login.toLowerCase() === account && isRepoId(installation?.id)) {
        return installation.id;
      }
    }
    if (payload.length < PAGE_SIZE) break;
  }
  throw new Error("GitHub App owner's installation was not found.");
}

function isScopedResponse(payload: Record<string, unknown> | null, repositoryId: number): boolean {
  if (payload?.repository_selection !== "selected") return false;
  const { repositories, permissions } = payload;
  if (!Array.isArray(repositories) || repositories.length !== 1) return false;
  const repository = repositories[0] as { id?: unknown; private?: unknown } | null;
  if (repository?.id !== repositoryId || repository.private !== false) return false;
  if (typeof permissions !== "object" || permissions === null || Array.isArray(permissions)) return false;
  const granted = permissions as Record<string, unknown>;
  return Object.keys(granted).length === 2 && granted.contents === "read" && granted.metadata === "read";
}

/**
 * Exchanges the App JWT for a token limited to one public repository with
 * read-only contents and metadata (V4-SEC-04). A response that grants more
 * than requested is refused, so a misconfigured installation cannot widen
 * what the Worker can read.
 */
async function mintToken(appId: string, pem: string, account: string, repositoryId: number): Promise<InstallationToken> {
  const jwt = await signJwt(appId, pem);
  const id = await findInstallation(jwt, account);
  const response = await fetchGitHub(`${REST}/app/installations/${id}/access_tokens`, {
    token: jwt,
    method: "POST",
    body: JSON.stringify({
      repository_ids: [repositoryId],
      permissions: { contents: "read", metadata: "read" },
    }),
  });
  const payload = await authJson(response, 201) as Record<string, unknown> | null;
  const token = payload?.token;
  const expiresAt = typeof payload?.expires_at === "string" ? Date.parse(payload.expires_at) : NaN;
  const refreshAt = Math.min(expiresAt - REFRESH_EARLY_MS, Date.now() + MAX_REUSE_MS);
  if (typeof token !== "string" || !/^[A-Za-z0-9._~+/-]+=*$/u.test(token) || token.trim() !== token
      || !Number.isFinite(refreshAt) || refreshAt <= Date.now() || !isScopedResponse(payload, repositoryId)) {
    throw new Error("Invalid GitHub App installation token response.");
  }
  return { token, refreshAt };
}

/**
 * Keeps one short-lived read credential in isolate memory (V4-SEC-04). The
 * cache is keyed by the binding values, not the `env` object, so a token
 * never outlives the key or account it was minted for, and a new `env`
 * object per request still reuses it.
 */
export class GitHubAppAuth {
  #state: { config: string; credential?: InstallationToken; retryAt: number } | undefined;
  #warned = false;

  private warn(): undefined {
    if (!this.#warned) {
      this.#warned = true;
      console.warn("GitHub App authentication unavailable. Using anonymous reads.");
    }
  }

  /** Reads the repository the token is scoped to, or undefined when it is not configured. */
  repositoryId(env: GitHubAppBindings | undefined): number | undefined {
    const value = env?.GH_APP_TOKEN_REPOSITORY_ID?.trim();
    if (!value || !/^[1-9]\d*$/u.test(value)) return undefined;
    const id = Number(value);
    return isRepoId(id) ? id : undefined;
  }

  /**
   * Forgets [token] after GitHub answered 401, so the next call mints a new
   * one. A different cached token, minted since, is left alone.
   */
  dropToken(token: string): void {
    if (this.#state?.credential?.token === token) delete this.#state.credential;
  }

  /**
   * Supplies a GitHub REST credential internally, or undefined while operating
   * anonymously. Without a configured repository ID the Worker stays anonymous.
   */
  async tokenFor(env: GitHubAppBindings | undefined): Promise<string | undefined> {
    const appId = env?.GH_APP_ID?.trim();
    const pem = env?.GH_APP_PRIVATE_KEY;
    const account = env?.GH_APP_INSTALLATION_ACCOUNT?.trim().toLowerCase();
    const repositoryId = this.repositoryId(env);
    if (!appId || !/^[1-9]\d*$/u.test(appId) || !pem || !account || repositoryId === undefined) return this.warn();
    // A digest, so the cache keeps no second copy of the key.
    const digest = new Uint8Array(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(pem)));
    const config = `${appId}\n${account}\n${repositoryId}\n${base64Url(digest)}`;
    if (this.#state?.config !== config) this.#state = { config, retryAt: 0 };
    const state = this.#state;
    if (state.credential && state.credential.refreshAt > Date.now()) return state.credential.token;
    if (state.retryAt > Date.now()) return undefined;

    // Concurrent callers each mint their own token instead of sharing one
    // promise: Workers refuse to resolve I/O started by another request.
    try {
      const minted = await mintToken(appId, pem, account, repositoryId);
      if (!state.credential || state.credential.refreshAt < minted.refreshAt) state.credential = minted;
      state.retryAt = 0;
      return state.credential.token;
    } catch {
      if (state.credential && state.credential.refreshAt > Date.now()) return state.credential.token;
      delete state.credential;
      state.retryAt = Date.now() + RETRY_MS;
      return this.warn();
    }
  }
}
