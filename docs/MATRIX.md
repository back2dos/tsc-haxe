# Test matrix

Generated 2026-10-11 by `tools/matrix.sh` at commit `66d0210`.
Regenerate: `make matrix` (or `tools/matrix.sh --help`). Only the targets that were run have values.

Each cell: passed/total. **Bold** with ✗: failures. "(1/N)": only every N-th input (deterministic sample).
"—": not run (see Notes).

| Suite | js | cpp | jvm | cs | py |
|---|---|---|---|---|---|
| unit tests (checks) | 435940/435940 | 404965/404965 | 435940/435940 | 435940/435940 | 435940/435940 |
| scanner (files) | 12445/12445 | 12445/12445 | 12445/12445 | 12445/12445 | 12445/12445 |
| scanner -trivia (files) | 12445/12445 | 12445/12445 | 12445/12445 | 12445/12445 | 12445/12445 |
| parser (files) | 12445/12445 | 12445/12445 | 12445/12445 | 12445/12445 | 12445/12445 |
| binder (files) | 12445/12445 | 12445/12445 | 12445/12445 | 12445/12445 | 12445/12445 |
| printer (files) | 12445/12445 | 12445/12445 | 12445/12445 | 12445/12445 | 12445/12445 |
| checker errors (cases) | 12797/12797 | 12797/12797 | 12797/12797 | 12797/12797 | 12797/12797 |
| checker types (cases) | 12157/12157 | 12157/12157 | 12157/12157 | 12157/12157 | 12157/12157 |
| checker symbols (cases) | 12157/12157 | 12157/12157 | 12157/12157 | 12157/12157 | 12157/12157 |
| checker js (cases) | 12728/12728 | 12728/12728 | 12728/12728 | 12728/12728 | 12728/12728 |
| checker map (cases) | 12797/12797 | 12797/12797 | 12797/12797 | 12797/12797 | 12797/12797 |
| checker sourcemap (cases) | 12797/12797 | 12797/12797 | 12797/12797 | 12797/12797 | 12797/12797 |
| checker trace (cases) | 145/145 | 145/145 | 145/145 | 145/145 | 145/145 |
| tsc + tsc -b (scenarios) | 376/377 (known¹) | 376/377 (known¹) | 376/377 (known¹) | 376/377 (known¹) | 376/377 (known¹) |
| real projects (compiler runs) | 16/16 | 16/16 | 16/16 | 16/16 | 16/16 |

## Wall time (seconds)

Run time of the target only (no build, no Go reference). The checker gate runs in parallel processes.

| Suite | js | cpp | jvm | cs | py |
|---|---|---|---|---|---|
| unit tests | 4.6 | 2.4 | 4.8 | 9.2 | 64.0 |
| scanner | 0.9 | 1.0 | 2.5 | 0.8 | 4.9 |
| scanner -trivia | 1.3 | 1.3 | 4.0 | 1.0 | 6.9 |
| parser | 1.2 | 1.6 | 6.4 | 1.3 | 13.1 |
| binder | 1.9 | 2.1 | 7.6 | 2.0 | 18.9 |
| printer | 1.8 | 0.8 | 1.9 | 1.7 | 25.3 |
| checker (all kinds, one run) | 31.9 | 32.5 | 61.2 | 61.2 | 344.2 |
| tsc + tsc -b | 6.3 | 6.0 | 3.5 | 6.2 | 63.9 |
| real projects | 80.8 | 41.4 | 46.3 | 85.6 | 1512.0 |
| **total** | 130.8 | 89.1 | 138.1 | 168.9 | 2053.1 |

## Notes

¹ tsc: `show-help-with-ExitStatus.DiagnosticsPresent_OutputsSkipped` fails on every target: the upstream reference is stale (upstream's own Go test fails on it at the pin; the output is identical to Go's actual output).


## Toolchains

| Tool | Version |
|---|---|
| haxe | 4.3.7 |
| hxcpp | 4.3.0 |
| hxjava | 4.2.0 |
| hxcs | 4.2.0 |
| hxnodejs | 12.2.0 |
| node | v20.20.2 |
| g++ | g++ (Ubuntu 13.3.0-6ubuntu2~24.04.1) 13.3.0 |
| java | openjdk version "21.0.12.1" 2026-08-18 LTS |
| dotnet | 8.0.425 |
| python | Python 3.12.3 |
