# M1 CourseOutline implementation notes

- Import previews and the managed manifest contract share a typed reader
  response. The preview mapper preserves assignment placement, emits pinned
  lesson and assignment hrefs, and reuses canonical video embeds from the
  validator. It omits submission limits and grading configuration.
- The cover remains a repository-relative display hint. The manifest contains
  no file sizes, so the mapper leaves `sizeBytes` absent. The DTO supports
  sizes supplied by pinned repository metadata.
- `just generate` regenerates and formats the Dart client. Flutter CI
  checks for tracked and untracked changes and runs the client decoding test.
  The client test uses the Flutter SDK test dependency already in the workspace.
- Root Dart analysis, TypeScript checking, the Python contract suites and
  the project rule check passed. Regeneration produced identical formatted
  Dart sources. The rule checker ran with explicit file arguments so it
  could skip Git-based file discovery.
- The sandbox denied loopback binds for workerd and the Flutter test runner.
  Both preview Vitest tests passed under Node, and the same client decoding
  assertions passed directly on the Dart VM.
