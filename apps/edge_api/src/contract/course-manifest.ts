import { Validator, type OutputUnit, type Schema } from "@cfworker/json-schema";
import { isAlias, isMap, isScalar, isSeq, LineCounter, parseDocument, type Node } from "yaml";
import schema from "../../../../spec/v4.0/schemas/course-v3.schema.json";
import { validateManifestSemantics } from "./course-manifest-semantics";
import type { CourseManifest, ValidationError, ValidationResult } from "./course-manifest-types";

export type { CourseManifest, ValidationError, ValidationResult } from "./course-manifest-types";

const MAX_MANIFEST_BYTES = 1024 * 1024;
const schemaValidator = new Validator(schema as Schema, "2020-12");
const schemaWrappers = new Set(["properties", "items", "$ref", "allOf", "if", "false"]);

type Failure = Extract<ValidationResult, { ok: false }>;

function failure(code: ValidationError["code"], path: string, message: string): Failure {
  return { ok: false, errors: [{ code, path, message }] };
}

function publicPointer(path: string): string {
  // A pointer can contain unrecognized mapping keys supplied by the author.
  // Use a complete ancestor pointer when a segment cannot safely be echoed.
  const unsafe = /[\p{Cc}\p{Cf}]/u.exec(path)?.index ?? path.length;
  const end = Math.min(unsafe, 80);
  return end >= path.length ? path : path.slice(0, Math.max(0, path.lastIndexOf("/", end)));
}

function keyPointer(path: string, key: string): string {
  return `${path}/${key.replaceAll("~", "~0").replaceAll("/", "~1")}`;
}

function nodeProperties(node: Node | null, path: string): Failure | undefined {
  if (isAlias(node) || node?.anchor !== undefined) {
    return failure("YAML_REFERENCE_FORBIDDEN", publicPointer(path), "YAML aliases and anchors are forbidden.");
  }
  if (node?.tag !== undefined) {
    return failure("YAML_TAG_FORBIDDEN", publicPointer(path), "Explicit YAML tags are forbidden.");
  }
  if (isScalar(node) && ((typeof node.value === "number" && !Number.isFinite(node.value))
      || (typeof node.value === "string" && !node.value.isWellFormed()))) {
    return failure("YAML_INVALID", publicPointer(path), "Use finite numbers and well-formed Unicode strings.");
  }
}

function inspectYaml(node: Node | null, path: string): Failure | undefined {
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
        return failure("YAML_INVALID", publicPointer(path), "YAML mapping keys must be strings.");
      }
      const child = keyPointer(path, key.value);
      const keyError = nodeProperties(key, child);
      if (keyError) return keyError;
      if (key.value === "<<") {
        return failure("YAML_MERGE_KEY_FORBIDDEN", publicPointer(child), "YAML merge keys are forbidden.");
      }
      if (keys.has(key.value)) {
        return failure("YAML_DUPLICATE_KEY", publicPointer(child), "YAML mapping keys must be unique.");
      }
      keys.add(key.value);
      const error = inspectYaml(pair.value ?? null, child);
      if (error) return error;
    }
  } else if (isSeq<Node | null>(node)) {
    for (const [index, item] of node.items.entries()) {
      const error = inspectYaml(item, `${path}/${index}`);
      if (error) return error;
    }
  }
}

function parseManifest(text: string): { ok: true; value: unknown } | Failure {
  const lines = new LineCounter();
  try {
    const document = parseDocument(text, {
      version: "1.2",
      schema: "core",
      merge: false,
      resolveKnownTags: false,
      uniqueKeys: false,
      prettyErrors: false,
      lineCounter: lines,
    });
    const issue = document.errors[0];
    if (issue?.code === "MULTIPLE_DOCS") {
      return failure("YAML_SINGLE_DOCUMENT", "", "Provide exactly one YAML document.");
    }
    if (issue?.code === "TAG_RESOLVE_FAILED") {
      return failure("YAML_TAG_FORBIDDEN", "", "Explicit YAML tags are forbidden.");
    }
    if (issue) {
      const { line, col } = lines.linePos(issue.pos[0]);
      const reason = issue.code.toLowerCase().replaceAll("_", " ");
      return failure("YAML_INVALID", "", `Invalid YAML at line ${line}, column ${col} (${reason}).`);
    }
    if (document.directives?.yaml.version !== "1.2") {
      return failure("YAML_VERSION_UNSUPPORTED", "", "Use YAML 1.2.");
    }
    const error = inspectYaml(document.contents, "");
    if (error) return error;
    if (!isMap(document.contents)) {
      return failure("YAML_SINGLE_DOCUMENT", "", "Provide one YAML document with a mapping at its root.");
    }
    if (document.warnings.length > 0) {
      return failure("YAML_INVALID", "", "The YAML document contains an unsupported directive or construct.");
    }
    return { ok: true, value: document.toJS({ maxAliasCount: 0 }) };
  } catch (error) {
    if (!(error instanceof RangeError)) throw error;
    return failure("YAML_INVALID", "", "The YAML document is too deeply nested to parse.");
  }
}

function schemaMessage(issue: OutputUnit, path: string): string {
  switch (issue.keyword) {
    case "additionalProperties":
      return "This field is not allowed.";
    case "pattern":
      if (path.endsWith("/path") || path === "/course/cover") {
        return "Use a canonical repository-relative path with no traversal, backslashes or URL schemes.";
      }
      if (path === "/course/homepage" || path.endsWith("/url")) return "Use an HTTPS URL.";
      return "The value does not match the required format for this field.";
    case "not":
      return "This combination of fields is not allowed.";
    case "oneOf":
      if (issue.keywordLocation.endsWith("/allOf/0/oneOf")) {
        return "Provide exactly one resource location, either path or url.";
      }
      return "The fields must match exactly one of the allowed shapes.";
    default:
      // The remaining diagnostics for this schema describe trusted constraints.
      return issue.error;
  }
}

function schemaErrors(issues: OutputUnit[]): ValidationError[] {
  const suppressedBranches = new Set<string>();
  const kindSuffix = "/properties/kind/const";
  for (const issue of issues) {
    if (issue.keywordLocation.endsWith(`/$ref${kindSuffix}`)) {
      suppressedBranches.add(issue.keywordLocation.slice(0, -kindSuffix.length));
    } else if (issue.keyword === "oneOf" && issue.keywordLocation.endsWith("At/oneOf")) {
      suppressedBranches.add(issue.keywordLocation);
    }
  }

  const errors = new Map<string, ValidationError>();
  const outlineErrors = new Map<string, ValidationError>();
  const branches = [...suppressedBranches];
  for (const [index, issue] of issues.entries()) {
    // An outline diagnosis should come from the branch for its declared kind.
    // Nullable timestamps have a single explanation for both branches.
    if (schemaWrappers.has(issue.keyword)
        || branches.some((branch) => issue.keywordLocation.startsWith(`${branch}/`))) continue;
    // The additionalProperties wrapper points at the object. Its false
    // subschema points at the exact rejected property.
    const next = issues[index + 1];
    const location = issue.keyword === "additionalProperties" && next?.keyword === "false"
      ? next.instanceLocation : issue.instanceLocation;
    const pointer = decodeURIComponent(location.slice(1));
    if (issue.keyword === "oneOf" && issue.keywordLocation.endsWith("/items/oneOf")) {
      outlineErrors.set(pointer, {
        code: "SCHEMA_INVALID",
        path: pointer,
        message: "Use an outline node with kind module, lesson or assignment and its required fields.",
      });
      continue;
    }
    const keyStart = pointer.lastIndexOf("/");
    const path = issue.keyword === "additionalProperties" && keyStart >= 0
      ? pointer.slice(0, keyStart) + publicPointer(pointer.slice(keyStart))
      : pointer;
    const message = suppressedBranches.has(issue.keywordLocation)
      ? "Use an RFC 3339 timestamp or null."
      : schemaMessage(issue, pointer);
    errors.set(`${path}\0${message}`, { code: "SCHEMA_INVALID", path, message });
  }
  const details = [...errors.values()];
  return details.concat([...outlineErrors.values()].filter(({ path }) =>
    !details.some((error) => error.path === path || error.path.startsWith(`${path}/`)),
  ).reverse());
}

/**
 * Validates course.yaml in size, safe YAML 1.2, Draft 2020-12 schema and
 * manifest semantic order (ADR-0003, FULL §4 item 10, SEC-014, SEC-020,
 * V4-CORE-04). Repository and publication state are checked by callers.
 */
export function validateCourseManifest(text: string): ValidationResult {
  if (text.length > MAX_MANIFEST_BYTES || new TextEncoder().encode(text).length > MAX_MANIFEST_BYTES) {
    return failure("MANIFEST_TOO_LARGE", "", "The manifest must be 1 MiB or smaller in UTF-8.");
  }
  if (!text.isWellFormed()) return failure("YAML_INVALID", "", "The manifest must be well-formed Unicode.");

  const parsed = parseManifest(text);
  if (!parsed.ok) return parsed;
  try {
    const structural = schemaValidator.validate(parsed.value);
    if (!structural.valid) {
      const errors = schemaErrors(structural.errors);
      return errors.length > 0 ? { ok: false, errors }
        : failure("SCHEMA_INVALID", "", "The document does not match the v3 course schema.");
    }
  } catch (error) {
    if (!(error instanceof RangeError)) throw error;
    return failure("SCHEMA_INVALID", "", "The document is too deeply nested to validate against the v3 schema.");
  }

  const manifest = parsed.value as CourseManifest;
  const errors = validateManifestSemantics(manifest);
  return errors.length === 0 ? { ok: true, manifest } : { ok: false, errors };
}
