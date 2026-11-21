/// <reference types="node" />

import { readFileSync } from "node:fs";
import { cpuUsage, version } from "node:process";
import { URL } from "node:url";
import { validateCourseManifest } from "../../src/contract/course-manifest.ts";

const runs = 20;
const warmups = 3;

function generateCourse(resourceCount: number): Uint8Array {
  const lines = [
    "schemaVersion: 3",
    "course:",
    "  id: benchmark",
    "  title: Benchmark course",
    "  summary: Generated benchmark fixture",
    "  language: en",
    "  version: 1.0.0",
    "assignments: []",
    "outline:",
  ];
  for (let start = 0; start < resourceCount; start += 100) {
    lines.push("  - kind: lesson", `    id: lesson-${start / 100}`, "    title: Lesson", "    resources:");
    for (let index = start; index < Math.min(start + 100, resourceCount); index++) {
      lines.push(
        `      - id: r-${index}`,
        "        title: Notes",
        "        type: pdf",
        "        path: notes.pdf",
      );
    }
  }
  return new TextEncoder().encode(lines.join("\n") + "\n");
}

const fixtures = [
  ["complete.course.yaml", readFileSync(new URL("../../../../spec/v4.0/examples/complete.course.yaml", import.meta.url))],
  ["200 resources", generateCourse(200)],
  ["2,000 resources", generateCourse(2_000)],
  ["10,000 resources", generateCourse(10_000)],
] as const;

console.log(`Node ${version}. CPU ms (user + system), ${runs} measured runs per fixture.`);
console.log("Fixture\tBytes\tMedian\tP95");
for (const [name, input] of fixtures) {
  const samples: number[] = [];
  for (let run = -warmups; run < runs; run++) {
    const start = cpuUsage();
    const result = validateCourseManifest(input);
    const { user, system } = cpuUsage(start);
    if (!result.ok) throw new Error(`${name}: ${JSON.stringify(result)}`);
    if (run >= 0) samples.push((user + system) / 1000);
  }
  samples.sort((a, b) => a - b);
  const midpoint = runs / 2;
  const median = (samples[midpoint - 1]! + samples[midpoint]!) / 2;
  const p95 = samples[Math.ceil(0.95 * runs) - 1]!;
  console.log(`${name}\t${input.byteLength}\t${median.toFixed(3)}\t${p95.toFixed(3)}`);
}
