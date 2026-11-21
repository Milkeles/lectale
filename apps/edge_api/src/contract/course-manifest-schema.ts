import type { ErrorObject } from "ajv";
import schema from "../../../../spec/v4.0/schemas/course-v3.schema.json" with { type: "json" };
import type { ManifestDiagnostics } from "./course-manifest-diagnostics";
import diagnosticValidators from "./generated/course-v3.diagnostics.js";
import validate from "./generated/course-v3.validate.js";

const { $defs, properties } = schema;
const outlineKinds = new Map([
  ["module", "module"],
  ["lesson", "lesson"],
  ["assignment", "assignmentRef"],
]);

type SchemaShape = {
  [keyword: string]: unknown;
  additionalProperties?: boolean;
  properties?: Record<string, SchemaShape>;
  items?: SchemaShape;
  oneOf?: readonly SchemaShape[];
  $ref?: string;
};

function object(value: unknown): Record<string, unknown> | undefined {
  if (value !== null && typeof value === "object" && !Array.isArray(value)) {
    return value as Record<string, unknown>;
  }
}

/** Checks v3 array and aggregate limits before Draft 2020-12 validation (FULL §4). */
export function checkManifestLimits(value: unknown, diagnostics: ManifestDiagnostics): void {
  function capped(value: unknown, { maxItems }: { maxItems: number }, path: string): readonly unknown[] {
    if (!Array.isArray(value)) return [];
    if (value.length <= maxItems) return value;
    diagnostics.report("SCHEMA_INVALID", path, `Limit this list to ${maxItems} items.`);
    return [];
  }

  const root = object(value);
  const course = object(root?.course);
  capped(course?.tags, properties.course.properties.tags, "/course/tags");
  capped(course?.authors, properties.course.properties.authors, "/course/authors");

  let nodeCount = 0;
  let resourceCount = 0;
  function countResources(count: number): boolean {
    resourceCount += count;
    if (resourceCount <= 10000) return true;
    diagnostics.report("TOO_MANY_RESOURCES", "", "Limit the combined lesson resources and assignment materials to 10,000.");
    return false;
  }

  function checkNodes(items: readonly unknown[], path: string, depth: number): boolean {
    if (depth > 5 && items.length > 0) {
      diagnostics.report("OUTLINE_TOO_DEEP", path, "Limit the outline to five levels of nodes.");
      return false;
    }
    nodeCount += items.length;
    if (nodeCount > 2000) {
      diagnostics.report("TOO_MANY_OUTLINE_NODES", "/outline", "Limit the outline to 2,000 total nodes.");
      return false;
    }
    for (const [index, item] of items.entries()) {
      const node = object(item);
      if (node?.kind === "module") {
        const childPath = `${path}/${index}/children`;
        const children = capped(node.children, $defs.module.properties.children, childPath);
        if (!checkNodes(children, childPath, depth + 1)) return false;
      } else if (node?.kind === "lesson") {
        const resources = capped(node.resources, $defs.lesson.properties.resources, `${path}/${index}/resources`);
        if (!countResources(resources.length)) return false;
      }
    }
    return true;
  }

  const outline = capped(root?.outline, properties.outline, "/outline");
  const assignments = capped(root?.assignments, properties.assignments, "/assignments");
  if (!checkNodes(outline, "/outline", 1)) return;
  for (const [index, item] of assignments.entries()) {
    const assignment = object(item);
    const path = `/assignments/${index}`;
    const fields = $defs.assignment.properties;
    const materials = capped(assignment?.materials, fields.materials, `${path}/materials`);
    if (!countResources(materials.length)) return;
    capped(object(assignment?.submission)?.allowedExtensions, fields.submission.properties.allowedExtensions,
      `${path}/submission/allowedExtensions`);
  }
}

function schemaMessage(issue: ErrorObject, path: string): string {
  switch (issue.keyword) {
    case "pattern":
      if (path.endsWith("/path") || path === "/course/cover") {
        return "Use a canonical repository-relative path with no traversal, backslashes or URL schemes.";
      }
      if (path === "/course/homepage" || path.endsWith("/url")) return "Use an HTTPS URL.";
      return "The value does not match the required format for this field.";
    case "not":
      return "This combination of fields is not allowed.";
    case "oneOf":
      return issue.schemaPath === "#/allOf/0/oneOf"
        ? "Provide exactly one resource location, either path or url."
        : "Use an RFC 3339 timestamp or null.";
    case "uniqueItems":
      return "Array items must be unique.";
    default:
      return issue.message ?? "The value does not match the course schema.";
  }
}

/** Collects schema errors one node at a time so the diagnostic budget bounds the work. */
function reportSchemaErrors(
  value: unknown, shape: SchemaShape, pointer: string, path: string, diagnostics: ManifestDiagnostics,
): void {
  const record = object(value);
  if (record && shape.additionalProperties === false && shape.properties) {
    for (const key in record) {
      if (Object.hasOwn(record, key) && !Object.hasOwn(shape.properties, key)) {
        diagnostics.unknownKey(path, key);
      }
    }
  }

  const check = diagnosticValidators[pointer]!;
  if (!check(value)) {
    for (const issue of check.errors ?? []) {
      if (issue.keyword === "if" || issue.schemaPath.includes("/oneOf/")) continue;
      const childPath = path + issue.instancePath;
      diagnostics.report("SCHEMA_INVALID", childPath, schemaMessage(issue, childPath));
    }
  }

  if (record && shape.properties) {
    for (const [key, child] of Object.entries(shape.properties)) {
      if ((child.items || child.properties) && Object.hasOwn(record, key)) {
        reportSchemaErrors(record[key], child, `${pointer}/properties/${key}`, `${path}/${key}`, diagnostics);
      }
    }
  }

  const item = shape.items;
  if (!Array.isArray(value) || !item) return;
  if (item.properties) {
    for (const [index, entry] of value.entries()) {
      reportSchemaErrors(entry, item, `${pointer}/items`, `${path}/${index}`, diagnostics);
    }
  } else if (item.$ref || item.oneOf) {
    for (const [index, entry] of value.entries()) {
      const childPath = `${path}/${index}`;
      const kind = object(entry)?.kind;
      const ref = item.$ref ?? (typeof kind === "string" ? outlineKinds.get(kind) : undefined);
      const name = ref?.replace("#/$defs/", "") as keyof typeof $defs | undefined;
      if (name) {
        reportSchemaErrors(entry, $defs[name], `#/$defs/${name}`, childPath, diagnostics);
      } else {
        diagnostics.report("SCHEMA_INVALID", childPath, "Use an outline node with kind module, lesson or assignment and its required fields.");
      }
    }
  }
}

/** Validates the full v3 schema with standalone Ajv code (FULL §4 item 10). */
export function validateManifestSchema(value: unknown, diagnostics: ManifestDiagnostics): void {
  if (validate(value)) return;

  const before = diagnostics.errors.length;
  reportSchemaErrors(value, schema, "#", "", diagnostics);
  if (diagnostics.errors.length === before) {
    diagnostics.report("SCHEMA_INVALID", "", "The manifest does not match the course schema.");
  }
}
