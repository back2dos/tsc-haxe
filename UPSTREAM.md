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
| real project (`make gate-realworld`): TypeScript 6 compiler sources (193k lines), declarations only / full emit with source maps | 154 / 308 files and diagnostics byte-identical |

## Performance (Phase 9, real project: TypeScript 6 compiler sources, 193k lines)

Wall time / peak memory, idle machine, `tools/gate/realworld.sh`. Go runs with `--singleThreaded`.

| Mode | Go | Haxe cpp | Haxe JS |
|---|---|---|---|
| declarations only | 1.17 s / 408 MB | 4.02 s / 1,030 MB | 5.82 s / 695 MB |
| full emit + source maps | 1.85 s / 543 MB | 5.66 s / 1,241 MB | 7.84 s / 958 MB |

Before Phase 9: cpp 5.16 s / 7.93 s, JS 6.66 s / 9.50 s. Remaining cost centres: hxcpp GC + allocation zeroing (~15–18% on cpp), string-keyed relation caches (~3%), Int boxing in generic code (~2%).

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
