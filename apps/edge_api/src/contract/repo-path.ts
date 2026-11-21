const REPO_PATH = /^[A-Za-z0-9_.-]+(?:\/[A-Za-z0-9_.-]+)*$/u;

/** Accepts canonical v3 manifest paths, including the allowlisted .well-known directory (SEC-020). */
export function isSafeRepoPath(path: string): boolean {
  return path.length <= 500 && REPO_PATH.exec(path)?.[0] === path
    && !path.split("/").some((part) => part.endsWith(".") || (part.startsWith(".") && part !== ".well-known"));
}
