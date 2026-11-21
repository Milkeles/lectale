import { Hono } from "hono";
import { requestId } from "hono/request-id";

import { errorResponse } from "./errors";

const app = new Hono<{ Bindings: Env }>().basePath("/api");

app.use(requestId());

// Deploys and uptime checks call this. It reads no binding, so a probe costs
// one request and almost no CPU.
app.get("/health", (c) =>
  c.json({ status: "ok" }, 200, { "Cache-Control": "no-store" }),
);

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
  console.error(JSON.stringify({ requestId: c.get("requestId"), name: error.name }));
  return errorResponse(500, {
    code: "internal",
    message: "Something went wrong on our side. Try again in a moment.",
    requestId: c.get("requestId"),
    retryable: true,
  });
});

export default app;
