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

## Security review fixes

The validator now decodes byte inputs as strict UTF-8, checks parser depth
and CST node count before YAML composition, and checks all schema array
caps and aggregate outline and resource caps before schema validation.
Schema validation processes list items individually and uses a Set for
submission extension uniqueness. Diagnostics stop at 50 entries or
8,192 UTF-16 code units of text, with `truncated: true` when more errors
would exceed either limit. Unknown-key excerpts share an 80-code-unit
budget and exclude Unicode line and paragraph separators.

YouTube and Vimeo resources validate the HTTPS origin and provider ID
before returning canonical embed URLs. External video links retain their
declared URLs. Repository paths reject trailing dots and timestamps
reject leap seconds. Regressions cover these checks and reject
`__proto__`, `constructor`, and `prototype` as manifest fields.

Across 20 measured Node runs per fixture, median and p95 CPU were
4.812 and 12.921 ms for the complete example, 17.274 and 23.304 ms for
200 resources, 161.392 and 219.397 ms for 2,000 resources, and
821.344 and 947.300 ms for 10,000 resources.
[CPU measurements](2026-11-21-m1-validator-cpu.md)

Typecheck and the four bundled spec scripts passed. The rule checker
reported no findings with explicit file paths. The sandbox denied
workerd's loopback bind, so the same assertions ran in Node with a
temporary Worker entry-point adapter for the health tests. All 169 passed.
