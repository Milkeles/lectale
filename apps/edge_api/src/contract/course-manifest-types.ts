interface Titled {
  id: string;
  title: string;
}

interface Described extends Titled {
  description?: string;
}

/** A lesson resource or assignment material (FULL §4 item 5). */
export type Resource = Described & {
  type: "auto" | "pdf" | "notebook" | "markdown" | "image" | "video"
    | "audio" | "text" | "code" | "file" | "folder" | "external";
  provider?: "youtube" | "vimeo" | "external";
  path?: string;
  url?: string;
  recursive?: boolean;
  maxEntries?: number;
  preview?: boolean;
  download?: boolean;
  language?: string;
  mediaType?: string;
  display?: "inline" | "attachment" | "auto";
};

/** An outline entry from course-v3.schema.json (FULL §4 item 4). */
export type OutlineNode =
  | (Described & { kind: "module"; children: OutlineNode[] })
  | (Described & { kind: "lesson"; recordedAt?: string | null; resources: Resource[] })
  | { kind: "assignment"; id: string; assignmentId: string };

interface Assignment extends Described {
  materials: Resource[];
  releaseAt?: string | null;
  submission: {
    allowedExtensions: string[];
    maxFileBytes: number;
    maxAttemptBytes: number;
    maxFiles: number;
    maxAttempts: number;
    maxTotalBytesPerStudent?: number;
    openAt?: string | null;
    dueAt?: string | null;
    closeAt?: string | null;
    allowLate?: boolean;
  };
  grading: {
    mode: "manual" | "automatic" | "hybrid";
    maxPoints: number;
    allowRevisionAfterGrade?: boolean;
    automatic?: {
      provider: "github-actions";
      workflowPath: string;
      trigger: "on-submit" | "manual";
      resultFormat: "course-grading-result/v1";
      timeoutMinutes: number;
      maxRunsPerAttempt: number;
      releasePolicy: "review-required" | "auto-release";
    };
  };
}

/**
 * Validated v3 course content (FULL §4). Policy decisions require evidence
 * from the repository and Worker beyond these author-supplied fields.
 */
export interface CourseManifest {
  schemaVersion: 3;
  course: Described & {
    summary: string;
    language: string;
    version: string;
    license?: string;
    tags?: string[];
    authors?: { name: string; url?: string }[];
    homepage?: string;
    estimatedMinutes?: number;
    level?: "introductory" | "intermediate" | "advanced" | "mixed";
    cover?: string;
    publishedAt?: string | null;
  };
  outline: OutlineNode[];
  assignments: Assignment[];
  display?: {
    showEstimatedDuration?: boolean;
    showFileDownloads?: boolean;
    themeAccent?: string;
  };
}

/**
 * A manifest diagnostic with a machine-readable code and a JSON pointer
 * (FULL §4 item 10, V4-CORE-04). The empty pointer denotes the document root.
 * An oversized or unsafe key is reported at its containing object.
 */
export interface ValidationError {
  code:
    | "MANIFEST_TOO_LARGE"
    | "YAML_INVALID"
    | "YAML_SINGLE_DOCUMENT"
    | "YAML_VERSION_UNSUPPORTED"
    | "YAML_DUPLICATE_KEY"
    | "YAML_REFERENCE_FORBIDDEN"
    | "YAML_MERGE_KEY_FORBIDDEN"
    | "YAML_TAG_FORBIDDEN"
    | "SCHEMA_INVALID"
    | "DUPLICATE_ASSIGNMENT_ID"
    | "DUPLICATE_NODE_ID"
    | "DUPLICATE_RESOURCE_ID"
    | "DUPLICATE_COURSE_TAG"
    | "UNKNOWN_ASSIGNMENT"
    | "UNREFERENCED_ASSIGNMENT"
    | "INVALID_REPO_PATH"
    | "INVALID_HTTPS_URL"
    | "RESOURCE_EXTENSION_MISMATCH"
    | "VIDEO_PROVIDER_MISMATCH"
    | "OUTLINE_TOO_DEEP"
    | "TOO_MANY_OUTLINE_NODES"
    | "TOO_MANY_RESOURCES"
    | "INVALID_ATTEMPT_SIZE"
    | "INVALID_TIMESTAMP"
    | "DATES_OUT_OF_ORDER";
  path: string;
  message: string;
}

/** The first failed validation phase, or validated content (FULL §4 item 10). */
export type ValidationResult =
  | { ok: true; manifest: CourseManifest }
  | { ok: false; errors: ValidationError[] };
