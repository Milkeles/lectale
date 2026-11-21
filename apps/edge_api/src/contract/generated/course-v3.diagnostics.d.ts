import type { ValidateFunction } from "ajv";

declare const validators: Readonly<Record<string, ValidateFunction>>;
export default validators;
