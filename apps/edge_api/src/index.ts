import { Hono } from "hono";
import { requestId } from "hono/request-id";
import { secureHeaders } from "hono/secure-headers";

import { errorResponse } from "./errors";
import type { GitHubReader } from "./github/reader";
import { GitHubRestReader } from "./github/rest-reader";
import type { PreviewCache } from "./preview/cache";
import { previewErrorResponse } from "./preview/errors";
import { registerPreviewRoutes } from "./preview/routes";

/** Composes the Worker routes with a replaceable GitHub reader and preview cache. */
export function createApp(reader: GitHubReader = new GitHubRestReader(), cache?: PreviewCache) {
  const app = new Hono<{ Bindings: Env }>().basePath("/api");

  app.use(requestId());
  app.use(
    secureHeaders({
      contentSecurityPolicy: { defaultSrc: ["'none'"], frameAncestors: ["'none'"] },
      referrerPolicy: "no-referrer",
      // Raw preview files supply their own sandbox policy.
      overwrite: false,
    }),
  );

  // Deploys and uptime checks call this. It reads no binding, so a probe costs
  // one request and almost no CPU.
  app.get("/health", (c) =>
    c.json({ status: "ok" }, 200, { "Cache-Control": "no-store" }),
  );

  registerPreviewRoutes(app, reader, cache);

  // Unknown routes answer with the standard envelope instead of Hono's plain
  // text, so clients only ever parse one error shape.
  app.notFound((c) =>
    errorResponse(404, {
      code: "not_found",
      message: "This API route does not exist.",
      requestId: c.get("requestId"),
      retryable: false,
    }),
  );

  // Never echo the exception: messages can contain paths, tokens or SQL.
  app.onError((error, c) => {
    const requestId = c.get("requestId");
    const previewFailure = previewErrorResponse(error, requestId);
    if (previewFailure) return previewFailure;
    console.error(JSON.stringify({ requestId, name: error.name }));
    return errorResponse(500, {
      code: "internal",
      message: "Something went wrong on our side. Try again in a moment.",
      requestId,
      retryable: true,
    });
  });

  return app;
}

export default createApp();
