import type { components } from "./generated/api";

/** The API's generated, privacy-safe error envelope (E7, V4-SEC-09). */
export type ApiError = components["schemas"]["ApiError"];

/** Builds the JSON response for [error] with caching disabled. */
export function errorResponse(status: number, error: ApiError, headers?: HeadersInit): Response {
  const responseHeaders = new Headers(headers);
  responseHeaders.set("Cache-Control", "no-store");
  return Response.json(error, { status, headers: responseHeaders });
}
