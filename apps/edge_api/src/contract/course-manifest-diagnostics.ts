import type { ValidationError } from "./course-manifest-types";

const MAX_ERRORS = 50;
const MAX_DIAGNOSTIC_TEXT = 8192;
const MAX_KEY_TEXT = 80;
const unsafeKey = /[\p{Cc}\p{Cf}\p{Zl}\p{Zp}]/u;

/** Adds an escaped key to a manifest JSON pointer (V4-CORE-04). */
export function keyPointer(path: string, key: string): string {
  return `${path}/${key.replaceAll("~", "~0").replaceAll("/", "~1")}`;
}

/** Finds a complete ancestor pointer when a YAML key cannot be echoed safely. */
export function publicPointer(path: string): string {
  const end = Math.min(unsafeKey.exec(path)?.index ?? path.length, MAX_KEY_TEXT);
  return end >= path.length ? path : path.slice(0, Math.max(0, path.lastIndexOf("/", end)));
}

/** Stops the current validation phase when its diagnostic budget is exhausted. */
export const diagnosticLimit = Symbol("manifest diagnostic limit");

/** Collects bounded diagnostics for one manifest validation phase (V4-CORE-04). */
export class ManifestDiagnostics {
  readonly errors: ValidationError[] = [];
  private textLength = 0;
  private keyLength = 0;

  /** Records a diagnostic or stops validation before it can exceed the budget. */
  report(code: ValidationError["code"], path: string, message: string): void {
    const length = code.length + path.length + message.length;
    if (this.errors.length === MAX_ERRORS || this.textLength + length > MAX_DIAGNOSTIC_TEXT) {
      throw diagnosticLimit;
    }
    this.errors.push({ code, path, message });
    this.textLength += length;
  }

  /** Uses a containing pointer when an unrecognized key exceeds the excerpt budget. */
  unknownKey(path: string, key: string): void {
    if (key.length <= MAX_KEY_TEXT - this.keyLength && !unsafeKey.test(key)) {
      const child = keyPointer(path, key);
      const length = child.length - path.length - 1;
      if (this.keyLength + length <= MAX_KEY_TEXT) {
        this.report("SCHEMA_INVALID", child, "This field is not allowed.");
        this.keyLength += length;
        return;
      }
    }
    this.report("SCHEMA_INVALID", path, "This field is not allowed.");
  }
}
