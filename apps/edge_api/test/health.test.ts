import { exports } from "cloudflare:workers";
import { describe, expect, it } from "vitest";

describe("GET /api/health", () => {
  it("answers ok without caching", async () => {
    const response = await exports.default.fetch("https://lectale.test/api/health");

    expect(response.status).toBe(200);
    expect(response.headers.get("Cache-Control")).toBe("no-store");
    expect(await response.json()).toEqual({ status: "ok" });
  });
});

describe("unknown /api routes", () => {
  it("return the standard error envelope", async () => {
    const response = await exports.default.fetch("https://lectale.test/api/nope");

    expect(response.status).toBe(404);
    const body = (await response.json()) as Record<string, unknown>;
    expect(body).toMatchObject({ code: "not_found", retryable: false });
    expect(typeof body.requestId).toBe("string");
  });
});
