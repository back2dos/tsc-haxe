# Upstream pin

All code under `src/ts/` is a port of the TypeScript 7 Go compiler. Port against this pin only.

| What | Value |
|---|---|
| Repository | https://github.com/microsoft/TypeScript |
| Tag | `v7.0.2` |
| Commit | `1e4744d68260a7cb91b62b12edc3f6a2187faaf1` |
| Go source | `tsc/internal/` (module `github.com/microsoft/typescript-go`) |
| Test corpus submodule | `tsc/_submodules/TypeScript` @ `4d4f005c8541e0255a9d8791205fdce326e462bc` |
| Go toolchain | `go1.26.9` (`GOTOOLCHAIN=go1.26.9`) |

Set up the reference checkout with `make upstream`.

## Gate status (latest run, 2026-10-10)

All results are identical on JS and cpp.

| Gate | Result |
|---|---|
| scanner, parser, binder, printer (`make gates`; 12,445 files each) | 0 diffs |
| checker + emit baselines (`make gate-checker`; 14,915 test configurations, skips as in Go) | errors 12,797, types 12,157, symbols 12,157, js 12,728 (11,714 .js references), map 12,797, sourcemap 12,797, trace 145 pass; **0 fail, 0 crash** |
| tsc + tsc -b scenarios (`make gate-tsc`; 377, watch excluded) | 376 pass; 1 fail: `show-help-with-ExitStatus.DiagnosticsPresent_OutputsSkipped` — the upstream reference is stale (upstream's own Go test fails on it at the pin; our output is byte-identical to Go's actual output) |
| real projects (`make gate-realworld`; deps pinned from upstream lock files, installed into `bin/`) | **4 projects, 32 compiler runs, all byte-identical to Go** (stdout, exit code, every output file incl. `.tsbuildinfo`): TypeScript 6 compiler sources (193k lines; decl + full emit); the whole TypeScript 6 solution via `tsc -b` (13 projects, 453k lines; clean, up-to-date, touch, edit, with and without `node_modules`); `_packages/native-preview` (`tsc -b`, 38k lines); `_extension` (3.5k lines) |

## Performance (Phase 9, real projects)

Wall time / peak memory, best of 3, idle machine, `tools/bench.sh`. Go runs with `--singleThreaded`.

| Workload | Go | Haxe cpp | Haxe JS |
|---|---|---|---|
| ts6-compiler (193k lines), declarations only | 1.14 s / 405 MB | 2.77 s / 852 MB | 5.66 s / 675 MB |
| ts6-compiler, full emit + source maps | 1.80 s / 521 MB | 3.87 s / 1,035 MB | 7.65 s / 927 MB |
| ts6-solution (`tsc -b`, 453k lines), clean | 3.55 s / 600 MB | 8.15 s / 1,311 MB | 15.28 s / 1,120 MB |
| native-preview, clean | 0.48 s / 220 MB | 1.16 s / 396 MB | 3.04 s / 444 MB |

History (ts6-compiler decl / full): before Phase 9, cpp 5.16 / 7.93 s, JS 6.66 / 9.50 s; after pass 1, cpp 4.02 / 5.66 s, JS 5.82 / 7.84 s; after pass 2, cpp 2.98 / 4.16 s. Pass 2 removed a quadratic text copy (native-preview cpp was 3.15 s / 1,345 MB) and most per-call allocations that Go does not make. Pass 3 replaced the binder's name-resolver function fields with typed methods and removed most remaining per-call result objects (cpp allocations −27% objects on full emit). Profiling tools: docs/PORTING.md §7a.

Remaining cost centres on cpp: GC + allocation (~20% incl. callees, of which ~4% is hxcpp re-sorting its block list on heap growth), live data about 2× Go (object headers, Dynamic fields, UTF-16). JS time is mostly V8 running the checker.

## Data files copied from upstream

| File | Source |
|---|---|
| `src/ts/diagnostics/diagnosticMessages.json` | `tsc/_submodules/TypeScript/src/compiler/diagnosticMessages.json` |
| `src/ts/diagnostics/extraDiagnosticMessages.json` | `tsc/internal/diagnostics/extraDiagnosticMessages.json` |
| `src/ts/bundled/libs/*.d.ts` (108 files) | `tsc/internal/bundled/libs/` |

## Port status

Order note (measured): `scanner` imports `ast` (Kind, TokenFlags, Node, SourceFile, NodeFactory), and Go has no import cycles. So the order is core → ast → scanner → parser.

Non-test Go lines, measured at the pin. "gen" = lines that upstream generates; we generate them too, we do not port them by hand.

| Layer | Package | Go LOC | gen | Status |
|---|---|---:|---:|---|
| 1 | core | 2669 | 184 | done |
| 1 | collections | 840 | 0 | done (go.GoMap for generic keys) |
| 1 | stringutil | 5573 | 4887 | done (tables generated) |
| 1 | tspath | 1435 | 0 | done |
| 1 | jsnum | 584 | 0 | done |
| 1 | debug | 61 | 0 | done |
| 1 | semver | 712 | 0 | done |
| 1 | json | 100 | 0 | done (thin layer over haxe.Json) |
| 1 | diagnostics | 9423 | 8804 | done (13 locales, generated from the .lcl files) |
| 1 | locale | 28 | 0 | done (+ golang.org/x/text/language port, 4,398 golden cases vs Go) |
| 2 | vfs | 3131 | 606 | done (all sub-packages incl. vfsmatch, vfstest) |
| 2 | bundled | 1110 | 568 | done (libs as haxe.Resource) |
| 4 | scanner | 4256 | 0 | done — Phase 2 gate: 12,445 files byte-identical (JS, cpp) |
| 3 | ast | 20847 | 10885 | done (generator + golden tests vs Go) |
| 4 | astnav | 783 | 0 | done |
| 5 | parser | 9071 | 0 | done — Phase 3 gate: 12,445 files byte-identical AST + diagnostics (JS, cpp) |
| 6 | binder | 3555 | 0 | done — Phase 4 gate: 12,445 files byte-identical symbols, flow graph, diagnostics (JS, cpp) |
| 7 | module | 2780 | 0 | done (golden: 108 resolutions, traces identical to Go) |
| 7 | packagejson | 662 | 0 | done |
| 7 | modulespecifiers | 2280 | 0 | done |
| 7 | outputpaths | 307 | 0 | done |
| 7 | tsoptions | 6101 | 0 | done — 165 upstream baselines byte-identical |
| 8 | evaluator | 168 | 0 | done |
| 8 | checker | 59818 | 25 | done — all errors/types/symbols baselines match |
| 8 | nodebuilder | 78 | 0 | done |
| 8 | pseudochecker | 1126 | 0 | done |
| 9 | printer | 11442 | 0 | done — print gate: 12,445 files byte-identical (JS, cpp) |
| 9 | sourcemap | 1013 | 0 | done |
| 9 | transformers | 24305 | 0 | done — all .js/.d.ts/source-map baselines match |
| 10 | compiler | 5658 | 0 | done (+ Phase 7 harness: `make gate-checker`) |
| 10 | diagnosticwriter | 506 | 0 | done |
| 10 | execute | 9348 | 0 | tsc CLI, tsc -b, incremental done; watch mode not ported |
| — | glob, nativepath, symlinks | 781 | 0 | done |
| — | tracing | 763 | 0 | done (xxh3 shim) |
| | **Total** | **190551** | **~26000** | |
