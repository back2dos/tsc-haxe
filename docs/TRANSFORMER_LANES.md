# Transformer lanes

The transformers (upstream `internal/transformers` and its 6 sub-packages, 24,305 Go lines) are ported by parallel lanes on a generated skeleton (`tools/gen/skeleton`), exactly like the checker. **The workflow and rules of `docs/CHECKER_LANES.md` apply unchanged**, with `ts.transformers` instead of `ts.checker`:

- private copies in `bin/lanes/<LANE>/ts/transformers/...` (plus the package's `import.hx`);
- compile with the lane directory **last**: `tools/haxe -cp src -cp bin/lanes/<LANE> -lib hxnodejs --macro 'include("ts.transformers")' -js bin/lanes/<LANE>/out.js`;
- signatures are fixed; merge into `src/` often; done = 0 `throw "unported` in your modules.

## Ownership

| Lane | Modules | Go source |
|---|---|---|
| T1 | `src/ts/transformers/estransforms/**` | `transformers/estransforms` (11,262 lines: downlevel ES features) |
| T2 | `src/ts/transformers/*.hx` (base), `declarations/**`, `inliners/**` | `transformers` (1,016), `declarations` (4,112: .d.ts emit), `inliners` (102) |
| T3 | `tstransforms/**`, `jsxtransforms/**`, `moduletransforms/**` | `tstransforms` (3,509: type erasure, TS-only syntax), `jsxtransforms` (1,209), `moduletransforms` (3,095: CommonJS/ESM) |

## Verification

- Port the upstream unit tests (only `tstransforms` has two) to `test/ts/transformers/...`.
- The real gate is the `.js` (and `.d.ts`) emit baselines, which lane H's harness (`tools/gate/checker.sh`, `test/ts/harness/`) compares once the checker is complete. Emit output must be byte-identical, so port printing-relevant details (synthesized nodes, emit flags, comments, helper names) exactly.
- Transformers depend on the checker through `printer.EmitResolver` (`src/ts/checker/Emitresolver.hx`, done). Calling checker code that is still a stub is fine at compile time.
