import { errorResponse, type ApiError } from "../errors";
import { GitHubReadError } from "../github/reader";

/** A public preview failure with a safe, generated API error body (V4-SEC-09). */
export class PreviewError extends Error {
  constructor(
    readonly status: number,
    readonly body: Omit<ApiError, "requestId">,
  ) {
    super(body.message);
    this.name = "PreviewError";
  }
}

/** Missing, private and unsafe preview targets have the same external failure (SEC-005). */
export function courseNotFound(): PreviewError {
  return new PreviewError(404, {
    code: "course_not_found",
    message: "This public course or file is unavailable.",
    retryable: false,
  });
}

/** Renders known preview failures. Unexpected failures go to the Worker's generic handler. */
export function previewErrorResponse(error: Error, requestId: string): Response | undefined {
  if (error instanceof GitHubReadError) {
    switch (error.kind) {
      case "not_found":
        error = courseNotFound();
        break;
      case "rate_limited": {
        const retryAfterSeconds = error.retryAfterSeconds ?? 60;
        return errorResponse(429, {
          code: "rate_limited",
          message: "GitHub is limiting preview requests. Try again shortly.",
          requestId,
          retryable: true,
          retryAfterSeconds,
        }, { "Retry-After": String(retryAfterSeconds) });
      }
      case "upstream":
        error = new PreviewError(502, {
          code: "github_unavailable",
          message: "GitHub could not provide the course. Try again shortly.",
          retryable: true,
        });
        break;
    }
  }
  if (error instanceof PreviewError) {
    return errorResponse(error.status, { ...error.body, requestId });
  }
}
