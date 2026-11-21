---
status: proposed
date: 2026-11-21
---

# Scoped resource addresses and a public preview route

## Context and problem statement

Two gaps stop the API from serving course content to the Flutter client.

E2: resource IDs are unique only inside their containing list
(`spec/v4.0/docs/YAML_V3_REFERENCE.md`, line 55: "unique within local
resources list"; `spec/v4.0/docs/SEMANTIC_VALIDATION.md`, line 5: "resource
IDs per containing list"). The content route is
`/api/courses/{id}/content/{resourceId}` (`spec/v4.0/api/openapi.yaml`, line
188). Two lessons can both hold a resource `slides`, so the route is
ambiguous.

E3: `POST /api/courses/import` returns a preview of a public repository
(`spec/v4.0/docs/API_SEMANTICS.md`; V4-CORE-01). But every content route
needs a D1 `courseId`, and an unclaimed repository has none. The anonymous
preview, which is the core product, cannot fetch a README, PDF or notebook.

## Decision drivers

- Keep `course-v3.schema.json` as the only manifest grammar
  (`spec/v4.0/AGENTS.md`: no YAML v4 dialect).
- V4-CORE-01, V4-CORE-02: preview needs no login and no registration.
- Cache keys use repository ID, 40-character SHA and a safe path
  (`spec/v4.0/docs/CACHING_PERFORMANCE_COST.md`, `public-course:v1:` key).
- No arbitrary upstream URL proxy.

## Considered options

- Composite address `{lessonId}/{resourceId}`, where the parent is the
  lesson or assignment that holds the resource.
- A path-scoped ID that the validator derives and returns in the manifest
  DTO.
- Require globally unique resource IDs (changes the schema; rejected by the
  schema rule above).
- For preview: reuse `/content/{resourceId}` with a fake course ID.
- For preview: a separate public route keyed by repository ID and SHA.

## Decision outcome

Proposed: use a path-scoped address and add a preview route.

- Resource address: `{parentId}/{resourceId}`, or an opaque address derived by
  the validator and returned in the manifest DTO. The client never builds it.
  The final form is chosen when the OpenAPI erratum is written (M1).
- Preview content: `GET /api/preview/{repoId}/{sha}/...`, where `repoId` is
  the numeric repository ID and `sha` the full commit SHA that import
  returned. It needs no auth and no D1 course row.

Cache class: the delivery plan said "class A". In the cache table,
class A is the hashed static app. SHA-keyed public content is class B, and
the repository-to-SHA lookup is class D (5 minutes; negative lookups at most
30 seconds). The preview route uses B for content and D for the lookup.

### Consequences

- Good, because the anonymous preview works end to end and caches by SHA.
- Good, because the schema and existing courses are unchanged.
- Bad, because the preview route duplicates part of the content route's
  logic. Share the path validation and the renderer-version key.
- Bad, because the client has two addressing modes (preview and managed
  course) until a course is registered.

### Confirmation

- Fixture: two lessons with the same resource ID resolve to different files.
- Test: preview of a public fixture repository returns README and a PDF with
  `Cache-Control: public` and a SHA-bearing key; a private repository or a
  traversal path returns the same safe error (V4-SEC-03, V4-CACHE-01).
- Contract test: preview and content responses never contain a token or
  `Set-Cookie`.

## More information

Becomes `accepted` when the owner approves errata E2 and E3. Planned for
M1 (contract) and M2 (preview slice).
