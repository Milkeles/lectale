# M1 validator CPU measurements

Run from `apps/edge_api` with Node 22.18 or later.

```sh
npm run compile:schemas
node test/contract/bench.ts
```

Both runs used Node v22.23.5 on Linux x86-64 with an Intel Xeon at 2.10 GHz.
Each fixture had three warmups and 20 measured runs per stage and for the
full validation call. All inputs were UTF-8 bytes. The generated block-style
YAML uses up to 100 PDF resources per lesson. The benchmark sums user and
system CPU time from `process.cpuUsage()`. Fixture setup runs outside the
measurements. YAML includes input limits, decoding and conversion to JS.
Schema includes the array and aggregate limit checks. Stage medians come
from separate samples and can differ from the median of the full call. The
full call also reports nearest-rank p95.

## Before

`yaml` 2.9.1, `@cfworker/json-schema` and the existing semantic rules.
All times are in milliseconds.

| Fixture | UTF-8 bytes | YAML median | Schema median | Semantics median | Total median | Total p95 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `complete.course.yaml` | 1,709 | 2.882 | 0.418 | 0.017 | 8.319 | 14.940 |
| 200 resources | 16,387 | 8.368 | 3.892 | 0.053 | 16.925 | 24.139 |
| 2,000 resources | 164,403 | 111.673 | 56.587 | 0.583 | 168.115 | 246.707 |
| 10,000 resources | 825,843 | 619.948 | 249.448 | 2.761 | 838.726 | 1,225.695 |

## After

Ajv 8.20.0 generates ESM validators from the Draft 2020-12 schema at build
time. `ajv-formats` 3.0.1 supplies the full `date-time` and `uri` checks.
The complete schema determines validity. A second group of generated
validators collects diagnostics per node so the existing limit can stop
collection and unrelated outline branches stay out of the error report.
[Ajv standalone validation code](https://ajv.js.org/standalone.html)

The installed `yaml` package already avoids pretty errors, source-token
capture and resolution of known explicit tags. Its built-in duplicate-key
check scans previous keys. The existing set-based check keeps that work
linear and retains exact duplicate-key pointers. `stringKeys: true`
would coerce numeric keys into strings, and `strict: false` would relax YAML
syntax checks. The parser now calculates line positions and escapes pointer
segments only on errors. It still checks depth and node limits before
composition and rejects aliases, anchors, explicit tags, duplicate keys and
non-1.2 YAML.

| Fixture | UTF-8 bytes | YAML median | Schema median | Semantics median | Total median | Total p95 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `complete.course.yaml` | 1,709 | 3.247 | 0.036 | 0.010 | 4.751 | 10.548 |
| 200 resources | 16,387 | 7.929 | 0.319 | 0.100 | 11.610 | 22.195 |
| 2,000 resources | 164,403 | 118.713 | 2.128 | 0.821 | 101.991 | 126.019 |
| 10,000 resources | 825,843 | 571.724 | 9.204 | 2.930 | 613.000 | 734.027 |

The bundled example was the only fixture below 10 ms at the local median.
Every fixture exceeded 10 ms at p95. YAML parsing still dominates, with a
572 ms median for the 10,000-resource fixture. The Workers Free plan allows
10 ms of CPU for the whole HTTP request. These measurements cover the
validator on local Node. Production Worker CPU remains unmeasured.
[Cloudflare Workers CPU limits](https://developers.cloudflare.com/workers/platform/limits/#cpu-time)
