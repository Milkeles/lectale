/**
 * The error body every `/api` route returns. Clients branch on [code] and
 * [retryable]; [message] is for people and never contains internal detail
 * (errata E7, `spec/v4.0/docs/ERROR_FAILURE_SEMANTICS.md`).
 */
export interface ApiError {
  code: string;
  message: string;
  requestId: string;
  retryable: boolean;
  retryAfterSeconds?: number;
}

/** Builds the JSON response for [error] with caching disabled. */
export function errorResponse(status: number, error: ApiError): Response {
  return Response.json(error, {
    status,
    headers: { "Cache-Control": "no-store" },
  });
}
