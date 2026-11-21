# M1 validator CPU measurements

Run from `apps/edge_api` with Node 22.18 or later.

```sh
node test/contract/bench.ts
```

Measured on Node v22.23.5, Linux x86-64, Intel Xeon at 2.10 GHz. Each
fixture had three warmups followed by 20 measured validations. The script
sums user and system CPU time from `process.cpuUsage()` and reports the
median and nearest-rank p95. File reads and generation run outside the
measurement. All four fixtures passed validation as UTF-8 bytes. The
generated block-style YAML uses up to 100 PDF resources per lesson.

| Fixture | UTF-8 bytes | Median CPU (ms) | p95 CPU (ms) |
| --- | ---: | ---: | ---: |
| `complete.course.yaml` | 1,709 | 4.812 | 12.921 |
| 200 resources | 16,387 | 17.274 | 23.304 |
| 2,000 resources | 164,403 | 161.392 | 219.397 |
| 10,000 resources | 825,843 | 821.344 | 947.300 |

Workers Free allows 10 ms of CPU per HTTP request. The bundled example's
local median was below that limit and its p95 was above it. All generated
courses exceeded 10 ms at both percentiles. The 10,000-resource course
used about 82 times the budget at the median. These local results leave
the production Worker CPU cost unmeasured. [Cloudflare Workers CPU limits](https://developers.cloudflare.com/workers/platform/limits/#cpu-time)
