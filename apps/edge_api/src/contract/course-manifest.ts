import { Composer, CST, isAlias, isMap, isScalar, isSeq, Lexer, Parser, type Node } from "yaml";
import { diagnosticLimit, keyPointer, ManifestDiagnostics, publicPointer } from "./course-manifest-diagnostics.ts";
import { checkManifestLimits, validateManifestSchema } from "./course-manifest-schema.ts";
import { validateManifestSemantics } from "./course-manifest-semantics.ts";
import type { CourseManifest, ValidationError, ValidationResult } from "./course-manifest-types";

export type { CourseManifest, ValidationError, ValidationResult } from "./course-manifest-types";

/** Shared UTF-8 byte limit for validation and streaming input (FULL §4 item 10). */
export const MAX_MANIFEST_BYTES = 1024 * 1024;
const MAX_YAML_DEPTH = 32;
const MAX_YAML_NODES = 250_000;
const yamlDepthLimit = Symbol("manifest YAML depth limit");
const yamlNodeLimit = Symbol("manifest YAML node limit");
const utf8 = new TextDecoder("utf-8", { fatal: true, ignoreBOM: true });

type Failure = Extract<ValidationResult, { ok: false }>;
type YamlPath = (string | number)[];

function failure(code: ValidationError["code"], path: string, message: string): Failure {
  return { ok: false, errors: [{ code, path, message }] };
}

function yamlFailure(code: ValidationError["code"], path: YamlPath, message: string): Failure {
  // Only invalid YAML needs an escaped pointer. Large valid outlines visit
  // many scalars even though they never produce a YAML diagnostic.
  let pointer = "";
  for (const segment of path) {
    pointer = typeof segment === "string" ? keyPointer(pointer, segment) : `${pointer}/${segment}`;
  }
  return failure(code, publicPointer(pointer), message);
}

function nodeProperties(node: Node | null, path: YamlPath): Failure | undefined {
  if (isAlias(node) || node?.anchor !== undefined) {
    return yamlFailure("YAML_REFERENCE_FORBIDDEN", path, "YAML aliases and anchors are forbidden.");
  }
  if (node?.tag !== undefined) {
    return yamlFailure("YAML_TAG_FORBIDDEN", path, "Explicit YAML tags are forbidden.");
  }
  if (isScalar(node) && ((typeof node.value === "number" && !Number.isFinite(node.value))
      || (typeof node.value === "string" && !node.value.isWellFormed()))) {
    return yamlFailure("YAML_INVALID", path, "Use finite numbers and well-formed Unicode strings.");
  }
}

function inspectYaml(node: Node | null, path: YamlPath): Failure | undefined {
  const propertiesError = nodeProperties(node, path);
  if (propertiesError) return propertiesError;
  if (isMap<Node, Node | null>(node)) {
    // Track keys in a set so wide untrusted mappings take linear time to check.
    const keys = new Set<string>();
    for (const pair of node.items) {
      const key = pair.key;
      if (!isScalar(key) || typeof key.value !== "string") {
        const keyError = nodeProperties(key, path);
        if (keyError) return keyError;
        return yamlFailure("YAML_INVALID", path, "YAML mapping keys must be strings.");
      }
      path.push(key.value);
      const keyError = nodeProperties(key, path);
      if (keyError) return keyError;
      if (key.value === "<<") {
        return yamlFailure("YAML_MERGE_KEY_FORBIDDEN", path, "YAML merge keys are forbidden.");
      }
      if (keys.has(key.value)) {
        return yamlFailure("YAML_DUPLICATE_KEY", path, "YAML mapping keys must be unique.");
      }
      keys.add(key.value);
      const error = inspectYaml(pair.value ?? null, path);
      if (error) return error;
      path.pop();
    }
  } else if (isSeq<Node | null>(node)) {
    for (const [index, item] of node.items.entries()) {
      path.push(index);
      const error = inspectYaml(item, path);
      if (error) return error;
      path.pop();
    }
  }
}

function* boundedYamlTokens(text: string): Generator<CST.Token> {
  let remainingNodes = MAX_YAML_NODES;
  function count(token: CST.Token | null | undefined): void {
    if (--remainingNodes < 0) throw yamlNodeLimit;
    if (!CST.isCollection(token)) return;
    for (const item of token.items) {
      if (item.key !== undefined) count(item.key);
      count(item.value);
    }
  }

  // yaml has no parse depth or node limit. Its maxAliasCount only applies
  // during toJS. Limit the parser stack, then check CST size before composition.
  const parser = new Parser();
  for (const lexeme of new Lexer().lex(text)) {
    for (const token of parser.next(lexeme)) {
      if (token.type === "document") count(token.value);
      yield token;
    }
    if (parser.stack.length > MAX_YAML_DEPTH) throw yamlDepthLimit;
  }
  for (const token of parser.end()) {
    if (token.type === "document") count(token.value);
    yield token;
  }
}

function syntaxPosition(text: string, offset: number): { line: number; col: number } {
  let line = 1;
  let start = 0;
  for (let end = text.indexOf("\n"); end !== -1 && end < offset; end = text.indexOf("\n", start)) {
    line++;
    start = end + 1;
  }
  return { line, col: offset - start + 1 };
}

function parseManifest(text: string): { ok: true; value: unknown } | Failure {
  try {
    const composer = new Composer({
      version: "1.2",
      schema: "core",
      merge: false,
      resolveKnownTags: false,
      uniqueKeys: false,
      prettyErrors: false,
    });
    const documents = composer.compose(boundedYamlTokens(text), true, text.length);
    const first = documents.next();
    if (first.done) return failure("YAML_SINGLE_DOCUMENT", "", "Provide exactly one YAML document.");
    const document = first.value;
    const issue = document.errors[0];
    if (issue?.code === "TAG_RESOLVE_FAILED") {
      return failure("YAML_TAG_FORBIDDEN", "", "Explicit YAML tags are forbidden.");
    }
    if (issue) {
      const { line, col } = syntaxPosition(text, issue.pos[0]);
      const reason = issue.code.toLowerCase().replaceAll("_", " ");
      return failure("YAML_INVALID", "", `Invalid YAML at line ${line}, column ${col} (${reason}).`);
    }
    if (!documents.next().done) {
      documents.return();
      return failure("YAML_SINGLE_DOCUMENT", "", "Provide exactly one YAML document.");
    }
    if (document.directives?.yaml.version !== "1.2") {
      return failure("YAML_VERSION_UNSUPPORTED", "", "Use YAML 1.2.");
    }
    const error = inspectYaml(document.contents, []);
    if (error) return error;
    if (!isMap(document.contents)) {
      return failure("YAML_SINGLE_DOCUMENT", "", "Provide one YAML document with a mapping at its root.");
    }
    if (document.warnings.length > 0) {
      return failure("YAML_INVALID", "", "The YAML document contains an unsupported directive or construct.");
    }
    return { ok: true, value: document.toJS({ maxAliasCount: 0 }) };
  } catch (error) {
    if (error === yamlNodeLimit) return failure("YAML_INVALID", "", "The YAML document exceeds the node budget.");
    if (error === yamlDepthLimit || error instanceof RangeError) {
      return failure("YAML_INVALID", "", "The YAML document exceeds the nesting budget.");
    }
    throw error;
  }
}

/** Parses bounded UTF-8 course.yaml bytes or text as safe YAML 1.2 (FULL §4 item 10). */
export function parseCourseManifest(input: string | Uint8Array): { ok: true; value: unknown } | Failure {
  const byteLength = typeof input === "string" ? input.length : input.byteLength;
  if (byteLength > MAX_MANIFEST_BYTES
      || (typeof input === "string" && new TextEncoder().encode(input).length > MAX_MANIFEST_BYTES)) {
    return failure("MANIFEST_TOO_LARGE", "", "The manifest must be 1 MiB or smaller in UTF-8.");
  }
  let text: string;
  try {
    text = typeof input === "string" ? input : utf8.decode(input);
  } catch (error) {
    if (!(error instanceof TypeError)) throw error;
    return failure("YAML_INVALID", "", "The manifest must be valid UTF-8.");
  }
  if (!text.isWellFormed()) return failure("YAML_INVALID", "", "The manifest must be well-formed Unicode.");

  return parseManifest(text);
}

/**
 * Validates UTF-8 course.yaml bytes or text, safe YAML 1.2, the v3 schema
 * and manifest rules (ADR-0003, FULL §4 item 10, SEC-014, SEC-020, V4-CORE-04).
 */
export function validateCourseManifest(input: string | Uint8Array): ValidationResult {
  const parsed = parseCourseManifest(input);
  if (!parsed.ok) return parsed;
  const diagnostics = new ManifestDiagnostics();
  const manifest = parsed.value as CourseManifest;
  try {
    checkManifestLimits(parsed.value, diagnostics);
    if (diagnostics.errors.length === 0) validateManifestSchema(parsed.value, diagnostics);
    if (diagnostics.errors.length === 0) validateManifestSemantics(manifest, diagnostics);
  } catch (error) {
    if (error !== diagnosticLimit) throw error;
    return { ok: false, errors: diagnostics.errors, truncated: true };
  }
  return diagnostics.errors.length === 0 ? { ok: true, manifest } : { ok: false, errors: diagnostics.errors };
}
