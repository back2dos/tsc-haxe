# Test matrix

Generated 2026-10-11 by `tools/matrix.sh --targets js,cpp,jvm,py --sample py=1` at commit `be3b66a`.
Regenerate: `make matrix` (or `tools/matrix.sh --help`). Only the targets that were run have values.

Each cell: passed/total. **Bold** with ✗: failures. "(1/N)": only every N-th input (deterministic sample).
"—": not run (see Notes).

| Suite | js | cpp | jvm | cs | py |
|---|---|---|---|---|---|
| unit tests (checks) | 435940/435940 | 404965/404965 | 435940/435940 | — | 435940/435940 |
| scanner (files) | 12445/12445 | 12445/12445 | 12445/12445 | — | 12445/12445 |
| scanner -trivia (files) | 12445/12445 | 12445/12445 | 12445/12445 | — | 12445/12445 |
| parser (files) | 12445/12445 | 12445/12445 | 12445/12445 | — | 12445/12445 |
| binder (files) | 12445/12445 | 12445/12445 | 12445/12445 | — | 12445/12445 |
| printer (files) | 12445/12445 | 12445/12445 | 12445/12445 | — | 12445/12445 |
| checker errors (cases) | 12797/12797 | 12797/12797 | 12797/12797 | — | 12797/12797 |
| checker types (cases) | 12157/12157 | 12157/12157 | 12157/12157 | — | 12157/12157 |
| checker symbols (cases) | 12157/12157 | 12157/12157 | 12157/12157 | — | 12157/12157 |
| checker js (cases) | 12728/12728 | 12728/12728 | 12728/12728 | — | 12728/12728 |
| checker map (cases) | 12797/12797 | 12797/12797 | 12797/12797 | — | 12797/12797 |
| checker sourcemap (cases) | 12797/12797 | 12797/12797 | 12797/12797 | — | 12797/12797 |
| checker trace (cases) | 145/145 | 145/145 | 145/145 | — | 145/145 |
| tsc + tsc -b (scenarios) | 376/377 (known¹) | 376/377 (known¹) | 376/377 (known¹) | — | 376/377 (known¹) |
| real projects (compiler runs) | 16/16 | 16/16 | 16/16 | — | 16/16 |

## Wall time (seconds)

Run time of the target only (no build, no Go reference). The checker gate runs in parallel processes.

| Suite | js | cpp | jvm | cs | py |
|---|---|---|---|---|---|
| unit tests | 4.8 | 4.3 | 7.9 | — | 111.9 |
| scanner | 1.1 | 1.2 | 2.7 | — | 5.1 |
| scanner -trivia | 1.3 | 1.3 | 4.1 | — | 7.2 |
| parser | 1.3 | 2.2 | 6.6 | — | 14.0 |
| binder | 2.0 | 2.0 | 7.8 | — | 19.7 |
| printer | 1.9 | 0.8 | 2.1 | — | 26.3 |
| checker (all kinds, one run) | 34.0 | 35.1 | 63.2 | — | 358.8 |
| tsc + tsc -b | 6.3 | 6.1 | 3.7 | — | 64.3 |
| real projects | 82.6 | 42.8 | 48.3 | — | 1526.5 |
| **total** | 135.4 | 95.9 | 146.4 | — | 2133.7 |

## Notes

¹ tsc: `show-help-with-ExitStatus.DiagnosticsPresent_OutputsSkipped` fails on every target: the upstream reference is stale (upstream's own Go test fails on it at the pin; the output is identical to Go's actual output).

- cs: not selected in this run (`--targets`).

## Toolchains

| Tool | Version |
|---|---|
| haxe | 4.3.7 |
| hxcpp | 4.3.0 |
| hxjava | 4.2.0 |
| hxnodejs | 12.2.0 |
| node | v20.20.2 |
| g++ | g++ (Ubuntu 13.3.0-6ubuntu2~24.04.1) 13.3.0 |
| java | openjdk version "21.0.12.1" 2026-08-18 LTS |
| dotnet | 8.0.425 |
| python | Python 3.12.3 |
