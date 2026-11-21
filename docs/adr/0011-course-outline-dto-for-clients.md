---
status: proposed
date: 2026-11-21
---

# CourseOutline DTO for reader clients

## Context and problem statement

The import preview response referenced the authoring schema for
`course.yaml`. The schema uses Draft 2020-12 conditionals to validate
resource types and assignment settings. The Dart generator
`swagger_parser` cannot process those conditionals, and the reader needs a
much smaller set of fields to navigate and render a course.

ADR-0003 keeps validation on the Worker. ADR-0008 gives resources scoped
content addresses so two lessons or assignments can share a local resource
ID and still use distinct links.

## Decision drivers

- V4-CORE-01 requires a public, pinned preview that opens from a GitHub link.
- V4-CORE-05 requires enough metadata to select an in-app viewer or give
  the reader a link or download.
- SEC-005 requires access checks for private content and file metadata.
- The Dart model must generate with the current OpenAPI tooling.

## Considered options

- Expose the validated authoring manifest.
- Expose a copy of the authoring schema with its conditionals removed.
- Project reader fields into a CourseOutline response.

## Decision outcome

Use `CourseOutline` in the import response and the managed-course manifest
response. It uses plain OpenAPI types with local references. The Worker
projects course metadata, ordered navigation, assignment dates, and
rendering hints from the validated manifest. Assignment links retain their
place in the outline and point to the corresponding assignment.

Repository resources carry a same-origin href. Public preview hrefs include
the repository ID and commit SHA. Managed course hrefs use the managed
content route, where the Worker checks access. URL-only resources carry a
null href and use a credential-free HTTPS link or the validator's canonical
player URL. Submission limits and grading configuration stay on the Worker.

### Consequences

- The Dart client can decode course content without a schema engine.
- The server owns the projection and must add fields as reader screens
  need them.
- A manifest alone supplies no file sizes. The response can include sizes
  when pinned repository metadata becomes available.

### Confirmation

The OpenAPI tests check both reader responses and the scoped href shape.
Vitest covers duplicate local IDs and canonical video embeds. The Dart test
decodes a nested preview, and CI checks for drift after regenerating and
formatting the client.

## More information

- [ADR-0003, server-only manifest validation](0003-validate-manifests-on-the-server-only.md)
- [ADR-0008, scoped resource addresses](0008-scoped-resource-addresses-and-public-preview-route.md)
- [V4-CORE acceptance cases](../../spec/v4.0/docs/RELEASE_TESTS_V4.md)
