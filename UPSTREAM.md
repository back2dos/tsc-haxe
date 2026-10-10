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

| Gate | JS | cpp |
|---|---|---|
| scanner, parser, binder, printer (12,445 files each) | 0 diffs | 0 diffs |
| checker `.errors.txt` (14,915 configs; 2,117 skipped as in Go) | 12,785 pass / 4 fail / 9 crash | same |
| checker `.types` (2,756 skipped) | 12,144 / 6 / 9 | same |
| checker `.symbols` (2,756 skipped) | 12,149 / 1 / 9 | same |
| tsc CLI scenarios (191; watch/build excluded) | 185 / 6 / 0 | 185 / 6 / 0 |

Not yet compared: `.js`, `.d.ts`, source-map and module-resolution baselines.

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
| 1 | diagnostics | 9423 | 8804 | messages + Format ported; localization not ported |
| 1 | locale | 28 | 0 | done (no tag matching) |
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
| 8 | checker | 59818 | 25 | ported (15 lanes on a generated skeleton); not yet gated (Phase 7) |
| 8 | nodebuilder | 78 | 0 | done |
| 8 | pseudochecker | 1126 | 0 | done |
| 9 | printer | 11442 | 0 | done — print gate: 12,445 files byte-identical (JS, cpp) |
| 9 | sourcemap | 1013 | 0 | done |
| 9 | transformers | 24305 | 0 | ported (lanes T1–T3); tstransforms unit tests pass; not yet gated (.js baselines) |
| 10 | compiler | 5658 | 0 | done (+ Phase 7 harness: `make gate-checker`) |
| 10 | diagnosticwriter | 506 | 0 | done |
| 10 | execute | 9348 | 0 | tsc CLI non-watch + incremental done (`make gate-tsc`); `tsc -b` and watch not ported |
| — | glob, nativepath, symlinks | 781 | 0 | done |
| — | tracing | 763 | 0 | done (xxh3 shim) |
| | **Total** | **190551** | **~26000** | |
