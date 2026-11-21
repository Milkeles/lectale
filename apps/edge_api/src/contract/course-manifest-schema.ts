import { validate, type OutputUnit, type Schema } from "@cfworker/json-schema";
import schema from "../../../../spec/v4.0/schemas/course-v3.schema.json" with { type: "json" };
import type { ManifestDiagnostics } from "./course-manifest-diagnostics";

const { $defs, properties } = schema;
const outlineKinds = new Map<string, Schema>([
  ["module", $defs.module as Schema],
  ["lesson", $defs.lesson as Schema],
  ["assignment", $defs.assignmentRef as Schema],
]);

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

const wrappers = new Set(["properties", "allOf", "if", "false"]);
const shallowSchemas = new WeakMap<Schema, {
  local: Schema;
  children: [string, Schema][];
}>();
const lookup: Record<string, Schema | boolean> = Object.create(null);

function shallow(shape: Schema) {
  const cached = shallowSchemas.get(shape);
  if (cached) return cached;

  // The v3 recursive edges are homogeneous lists and named child objects.
  // Keep scalar properties and local combinations in the schema evaluator.
  const { items, uniqueItems, additionalProperties, properties, ...local } = shape;
  const children: [string, Schema][] = [];
  if (properties) {
    local.properties = Object.create(null);
    for (const [key, field] of Object.entries(properties)) {
      if (typeof field === "object" && (field.items || field.properties)) {
        children.push([key, field]);
      } else {
        local.properties[key] = field;
      }
    }
  }
  const entry = { local, children };
  shallowSchemas.set(shape, entry);
  return entry;
}

function schemaMessage(issue: OutputUnit, path: string): string {
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
      return issue.keywordLocation.endsWith("/allOf/0/oneOf")
        ? "Provide exactly one resource location, either path or url."
        : "Use an RFC 3339 timestamp or null.";
    default:
      return issue.error;
  }
}

/** Validates the v3 schema in bounded units so bad lists cannot accumulate schema errors. */
export function validateManifestSchema(value: unknown, diagnostics: ManifestDiagnostics): void {
  function check(value: unknown, shape: Schema, path: string): void {
    const record = object(value);
    if (record && shape.additionalProperties === false && shape.properties) {
      for (const key in record) {
        if (Object.hasOwn(record, key) && !Object.hasOwn(shape.properties, key)) {
          diagnostics.unknownKey(path, key);
        }
      }
    }

    const { local, children } = shallow(shape);
    const result = validate(value, local, "2020-12", lookup, false);
    for (const issue of result.errors) {
      if (wrappers.has(issue.keyword) || issue.keywordLocation.includes("At/oneOf/")) continue;
      const pointer = path + decodeURIComponent(issue.instanceLocation.slice(1));
      diagnostics.report("SCHEMA_INVALID", pointer, schemaMessage(issue, pointer));
    }

    if (record) {
      for (const [key, child] of children) {
        if (Object.hasOwn(record, key)) check(record[key], child, `${path}/${key}`);
      }
    }

    const item = shape.items;
    if (!Array.isArray(value) || typeof item !== "object" || Array.isArray(item)) return;
    // The v3 uniqueItems list requires strings. Invalid item types fail below.
    if (shape.uniqueItems && new Set(value).size !== value.length) {
      diagnostics.report("SCHEMA_INVALID", path, "Array items must be unique.");
    }
    // Outline oneOf branches have distinct kind constants. Checking the selected
    // branch avoids revalidating children and reporting errors from other kinds.
    const ref = item.$ref?.slice("#/$defs/".length);
    const definition = ref ? ($defs as Record<string, Schema>)[ref] : undefined;
    for (const [index, entry] of value.entries()) {
      const childPath = `${path}/${index}`;
      const kind = item.oneOf ? object(entry)?.kind : undefined;
      const child = item.oneOf ? (typeof kind === "string" ? outlineKinds.get(kind) : undefined) : definition ?? item;
      if (child) {
        check(entry, child, childPath);
      } else {
        diagnostics.report("SCHEMA_INVALID", childPath, "Use an outline node with kind module, lesson or assignment and its required fields.");
      }
    }
  }

  check(value, schema as Schema, "");
}
