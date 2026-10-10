# Checker lanes

The checker (upstream `internal/checker`, 59,818 Go lines) is ported by parallel lanes on a generated skeleton (`tools/gen/skeleton`, report in `docs/checker-skeleton-report.txt`). Every function already exists with its signature; its body is `throw "unported: ... (<file>.go:<line>)"`. A lane replaces stub bodies with the faithful port of the Go body. `docs/PORTING.md` applies in full.

## Ownership (one lane per row; edit only your modules)

| Lane | Modules (`src/ts/checker/`) | Go source |
|---|---|---|
| F | `Checker.hx` (types at the top, `Checker` fields + constructor, **all package-level funcs of all files**), `Utilities.hx`, `StringerGenerated.hx`, `Jsdoc.hx` | package-level funcs of every file; utilities.go; jsdoc.go |
| P1 … P8 | `CheckerPart<N>.hx` | `checker.go`, the line range in the module header |
| O1 | `Relater.hx` | relater.go |
| O2 | `Nodebuilderimpl.hx`, `Nodebuilder_.hx`, `NodebuilderHover.hx`, `Nodebuilderscopes.hx`, `Pseudotypenodebuilder.hx`, `Symboltracker.hx`, `Printer_.hx` | nodebuilder*.go, pseudotypenodebuilder.go, symboltracker.go, printer.go |
| O3 | `Flow.hx`, `Inference.hx` | flow.go, inference.go |
| O4 | `Grammarchecks.hx`, `Jsx.hx` | grammarchecks.go, jsx.go |
| O5 | `Types.hx`, `Mapper.hx`, `Emitresolver.hx`, `Services.hx`, `Exports.hx`, `Tracer.hx` | types.go, mapper.go, emitresolver.go, services.go, exports.go, tracer.go |
| O6 | `Nodecopy.hx`, `Symbolaccessibility.hx` | nodecopy.go, symbolaccessibility.go |

`import.hx` belongs to the lead. Need a change there? Report it.

## Private-copy workflow (lanes never break each other)

1. Copy your modules **and `src/ts/checker/import.hx`** to `bin/lanes/<LANE>/ts/checker/` and edit **only those copies** while you work.
2. Compile with your directory **last** on the classpath (measured: Haxe 4.3.7 takes the module from the **later** `-cp`; with the wrong order your code is silently not compiled at all):
   ```
   tools/haxe -cp src -cp bin/lanes/<LANE> -lib hxnodejs --macro 'include("ts.checker")' -js bin/lanes/<LANE>/out.js
   ```
   Check once that your copy is really used (e.g. a deliberate type error in it must fail the build).
   JS type-checks the whole checker in seconds. Run the hxcpp build once at the end, from `src` after merging: `tools/haxe -cp src -cp bin/lanes/<LANE>/main --macro 'include("ts.checker")' -main <LANE>Main -cpp bin/lanes/<LANE>/cpp -D HXCPP_QUIET -D HXCPP_CHECK_POINTER` with a trivial `bin/lanes/<LANE>/main/<LANE>Main.hx`.
3. When your modules compile, copy them into `src/ts/checker/` and compile once more with `-cp src` only. If it breaks because of another lane's merged code, fix **your** side; if the cause is theirs, report it.
4. Merge often, at least every time a large group of functions is done, so the other lanes see real code instead of stubs.

## Rules

- **Rest-argument extension methods as values:** Haxe 4.3.7 compiles a bound closure of a rest-args extension method (e.g. `c.error` stored as a function value) so that the rest array is passed as one argument. Write an explicit closure that spreads the arguments instead.
- Go `iter.Seq` in the checker skeleton is the yield-callback form; convert to `Iterator` only at a call into `core` that takes an `Iterator`.
- `ResolutionMode*` constants are `Core.ResolutionMode*`.

- **Signatures are fixed.** Do not change parameters, return types or names of skeleton functions; other lanes call them. If a signature is wrong (generator mistake), fix it only in your own module and report it with all call sites you know of. Hot-path deviations (out parameters instead of `go.Tuple`) are **not** allowed in the checker for now; we measure first (Phase 9).
- Port bodies faithfully, in Go order. Keep the Go doc comments the skeleton placed.
- Calling a function owned by another lane that is still a stub is fine: it compiles and only throws at run time.
- Struct map keys (`/* key: T */` comments in the skeleton): encode the key as a `String` in a helper next to the key type, and use the same helper everywhere. Report the helper.
- Count what is left: `grep -c 'throw "unported' <module>`. Your lane is done when it is 0 (or every remaining stub is listed with a reason).
- There are no checker unit tests upstream. Correctness is checked later by the baseline gate (`.types`, `.symbols`, `.errors.txt`). So read each Go function completely, and port operator precedence (§3a), `switch`/`break` (§4) and nil slices exactly.

## Final report (per lane)

Modules; stubs left (should be 0); signature fixes; key helpers; each `// PORT:` deviation (one line); PORTING.md rules that did not fit.
