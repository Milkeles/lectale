# M1 course manifest validator

Implemented the Worker-only `validateCourseManifest(text)` API in
[`apps/edge_api/src/contract/`](apps/edge_api/src/contract/). It checks the
UTF-8 byte limit, safely parses one YAML 1.2 mapping, validates it against
the imported Draft 2020-12 course schema, and applies manifest semantics in
that order. Failures give a stable code, JSON pointer and bounded diagnostic.

- YAML checks reject duplicate keys, anchors, aliases, merge keys, explicit
  tags, malformed input and non-JSON scalar values.
- Semantic checks cover outline, assignment and resource ID scopes, course
  tag uniqueness, assignment references, repository path safety, resource
  extensions, HTTPS URLs, video provider hosts, outline depth, aggregate node
  and resource limits, submission size limits and chronological timestamps.
- Checks involving a pinned Git tree, folder contents, the root README,
  publication snapshots, authorization or D1 approvals require integration
  context. The schema checks the corresponding manifest fields where defined.

The normative rules make outline IDs global and include `releaseAt` in
timestamp ordering. The five-level limit counts actual nodes, so an empty
child list on a fifth-level module is valid. The spec leaves file suffixes
open-ended. The validator uses common extensions for typed media and accepts
extensionless or project-specific names for text and code. `.well-known`
follows the Python reference's dotfile exception. Unreferenced assignments
are rejected under the default policy.

## Verification

- TypeScript typecheck passed using Wrangler runtime declarations generated
  by the bundled workerd type generator without a listening socket.
- The 134 new contract cases passed in Vitest's Node runner. The same cases
  and two existing health cases passed in direct workerd using a temporary
  test adapter, for 136 passed and zero failed.
- All four bundled Python test scripts passed. The project rule checker
  exited successfully with no output using explicit repository paths.
- The standard `npm test` runner attempted to bind `127.0.0.1` and the
  sandbox returned `EPERM` before either test file could execute.
