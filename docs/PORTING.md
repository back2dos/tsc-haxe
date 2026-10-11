# Porting rules: Go (TS 7) → Haxe

Every lane follows these rules. The goal is a **faithful** port: same names, same control flow, same output. Baselines only stay useful while we do not diverge. No improvements, refactors or features during the port.

Mark every forced deviation with `// PORT: <reason>`.

## 1. Names and files

| Go | Haxe |
|---|---|
| package `internal/foo` | package `ts.foo`, directory `src/ts/foo/` |
| file `foo_bar.go` | module `src/ts/foo/FooBar.hx`. It holds the types and methods of that file. |
| package-level funcs, vars, consts of package `foo` (all files) | static members of the **package class** `ts.foo.Foo` in `Foo.hx`. Keep Go file order and put `// --- bar.go ---` above each group. |
| type `Foo` in package `foo` (e.g. `scanner.Scanner`) | same class as the package class: struct members are instance members, package-level items are statics. |
| a Go file whose module name would clash with an imported class (`diagnostics.go` in tsoptions) | suffix `_`: `Diagnostics_.hx` |
| a non-test Go helper package used only by tests (`tsoptionstest`) | lives under `src/ts/<pkg>/<helper>/` like any package |
| unexported Go **type** name (`specialCasingMapping`) | Haxe type names must start upper case: capitalize the first letter (`SpecialCasingMapping`). If that clashes with an exported type, append `_`. Functions, fields and vars keep the exact Go name. |
| identifiers | **exactly the Go name**, case included (`GetSymbol` and `getSymbol` are different members in Go and in Haxe). |
| identifier that is a Haxe keyword (`function`, `operator`, `overload`, `new`, `default`, `in`, `this`, `cast`, `inline`, `final`, `dynamic`, `override`, `static`, `extern`, `enum`, `abstract`, `macro`, `untyped`, `using`, `is`, …) | append `_`: `function_`. Same for the name `trace` (a call `trace(...)` silently goes to `haxe.Log.trace`) and for locals. |
| each package directory | an `import.hx` that imports the modules of its own package and the packages it uses. Then a Go call `ast.IsIdentifier(n)` becomes `Ast.IsIdentifier(n)` — a mechanical change. |

Example, Go `scanner.TokenToString(kind)` → Haxe `Scanner.TokenToString(kind)`.

## 2. Methods split over many files

Go `*Checker` has methods in 15 files (`checker.go` alone is 32k lines). A Haxe class lives in one file. Therefore:

- Methods from the main file (`checker.go`) are instance methods of `class Checker` in `Checker.hx`.
- Methods from another file (`relater.go`) are statics in `class Relater` (module `Relater.hx`) with the receiver as first parameter: `public static function isTypeRelatedTo(c:Checker, ...)`.
- The package `import.hx` has `using ts.checker.Relater;` for every such file. Then `c.isTypeRelatedTo(...)` works the same in every file, as in Go.
- `using` does not apply to the implicit `this`: inside the main class write `this.isTypeRelatedTo(...)` for an extension method.
- A `switch` on an enum abstract may fail with "Unmatched patterns": add `default:` (with Go's behaviour for that case).
- An enum-abstract value defined from other values (`NodeFlagsAwaitUsing = Const | Using`) or a non-literal constant cannot be a `switch` pattern: use an `if`/`else` chain.

## 3. Types

| Go | Haxe |
|---|---|
| `struct` | `class` with `public var` fields and a `new()`. |
| struct zero value | **Every field has an initializer equal to the Go zero value**: `Int = 0`, `Float = 0.0`, `Bool = false`, `String = ""`, pointer/slice/map = `null`. Required: on JS an uninitialized `Int` is `null`, not `0`. |
| struct used as a value (copied on assignment, e.g. `ScannerState`, `core.TextRange`) | class with a `copy()` method. Every Go copy that is later mutated becomes an explicit `.copy()`. Immutable value types (all fields `final`) need no copy. |
| embedded struct | composition field with the Go type name (`s.ScannerState.pos`); promoted fields that call sites use are reached through forwarding properties on the outer class. Exception: on a measured hot path the embedded fields may be flattened into the outer class (as `Scanner` does with `ScannerState`); then `Mark()`/copy methods copy the fields. Mark with `// PORT: flattened`. Inheritance only where the Go design is a base type (AST node data). |
| `interface` | `interface`. Go interfaces are structural; where an existing Haxe class must satisfy a Go interface it does not declare (e.g. `SourceFile` as `FileLike`), use a small adapter class, cached per object when Go uses the value as a map key. A Go type switch → `Std.downcast` / `Std.isOfType`; prefer an existing `Kind` switch where Go has one. |
| typed consts with `iota` (enums, flag sets) | `enum abstract T(Int)`, values keep the Go name (`Category.CategoryError`). Flag sets add `@:op(A | B)`, `@:op(A & B)`, `@:op(~A)`. Test flags with `!= 0`, **never** with `<` or `>` (bit 31 is the sign bit in Haxe). Ordered comparison of a non-flag enum abstract without `@:op` → compare `(x : Int)`. Locals named like Haxe keywords get `_` too (`operator_`). |
| `int`, `int32`, `uint32` | `Int`. Positions, ids and all flag types fit in 32 bits (measured). A `uint32` **value read from input** (e.g. semver numbers) can exceed 2^31-1: keep the bit pattern in `Int`, compare with unsigned helpers, print unsigned. |
| `int64`/`uint64` arithmetic that needs 64 bits (hashes, ids) | `haxe.Int64`. Mark with `// PORT: 64-bit`. |
| `float64` | `Float` |
| `jsnum.Number` inside a Go `any` | A `jsnum.Number` inside a Go `any` is a raw `Float`; -0 through `any` is lost on hxcpp (documented deviation). |
| `[]T` | `Array<T>`. A `range` over a nil slice or map, and a spread `f(xs...)` of a nil slice, are made safe **automatically** by the `go.NilRange` build macro (`tools/haxe` applies it to packages `ts` and `go`): `for (x in null)` runs zero times, `...null` passes zero arguments, `[for (x in null) ...]` gives `[]`. `len(nil)` is **not** covered: use `Core.len(s)` or a null check. Every empty parser `NodeList` has `Nodes == null` (Go nil). Go `append` may write into a shared backing array; Haxe `push` always mutates the caller's array. Where a callee's append must not be visible to the caller, copy first (`s.copy()` then `push`). `nil` slice → `null`; `len(s)` on a possibly-nil slice → `Core.len(s)` helper or a null check. `append(s, x)` → `s.push(x)` only when the Go code owns `s`; otherwise copy. |
| `map[string]T` / `map[int]T` / `map[*T]U` | `haxe.ds.StringMap` / `haxe.ds.IntMap` / `go.IdentityMap` (never `haxe.ds.ObjectMap` or a `Map<SomeClass, V>`, see §7a). **Go map iteration order is random; upstream never depends on it. If a Haxe port does, it is a bug.** |
| multiple return values | shared types in `go.Tuple` (deliberately **not** `@:generic`: that breaks inside generic functions and hangs Haxe 5 preview): `ValueOk<T>` for `(T, bool)`, `ValueError<T>` for `(T, error)`, `Pair<A, B>`, `Triple<A, B, C>`. A specific class only when it has a real name in Go. On hot paths (per character, per node) prefer an out parameter or return one value and derive the other. **No anonymous structures** (slow on hxcpp/HL). |
| `error` | interface `go.Errors.Error` (`Error():String`); `nil` → `null`; `errors.New` → `Errors.New`. |
| function values / closures | Haxe function types. |
| generics | Haxe type parameters; small helpers `inline`. |

## 3a. Operator precedence (correctness trap)

Go and Haxe disagree. Go: `* / % << >> & &^` bind tighter than `+ - | ^`, which bind tighter than comparisons. Haxe: `<< >> >>>` bind **looser** than `+ -`, and `& | ^` all have the **same** precedence.
- Go `1<<30 - 1` = `(1<<30) - 1`; Haxe `1<<30 - 1` = `1<<29`.
- Go `a | b & c` = `a | (b & c)`; Haxe = `(a | b) & c`.
- Go `a + b & c` = `a + (b & c)`; Haxe = `(a + b) & c`.

**Rule:** every expression that mixes shift or bit operators with any other binary operator gets explicit parentheses that encode Go's grouping. Go `&^` → `a & ~b`.

## 3b. AST (`ts.ast`)

- `Node` is `@:forward abstract Node(NodeDefault)` (Go `*Node` methods + `As*()` casts). Per-kind classes `extends NodeDefault`; all Go base fields are flattened. See the header of `tools/gen/ast/GenAst.hx`.
- A promoted Go `*Node` method called on a data struct: `x.AsNode().M()`.
- `As*()` is an unchecked cast in Go terms; on hxcpp a wrong kind gives `null`, not a panic. A null access on hxcpp segfaults unless built with `-D HXCPP_CHECK_POINTER` (on in all cpp test builds).
- Node kinds and flags in comparisons/switches need wildcard imports (`import ts.ast.KindGenerated.Kind.*` style) in the package `import.hx`.
- Unexported Go package functions → `private static` with `@:allow(ts.<pkg>)`.
- Generated code lives in `KindGenerated.hx`, `AstGenerated.hx` and marked regions of `Ast.hx`. Never edit inside `BEGIN GENERATED` / `END GENERATED`; change `tools/gen/ast` and re-run it.

## 4. Statements

| Go | Haxe |
|---|---|
| `defer f()` | Haxe has no `finally`. If the body has no early `return`: `try { body } catch (e:Dynamic) { f(); throw e; } f();`. With early returns: move the body into a local function: `final r = try body() catch (e:Dynamic) { f(); throw e; }; f(); return r;`. A `defer` that restores state on the success path only (common in the checker) may be written at each `return`. |
| `panic(x)` | `throw x` |
| `for i := range n` / `for i, x := range s` | `for (i in 0...n)` / `for (i in 0...s.length) { final x = s[i]; ... }` |
| Go `break` inside a `switch` (leaves the switch) | **never** a Haxe `break` (in Haxe it leaves the enclosing loop). Restructure with `if`/`else`. Conversely, Go `break label` to the loop around the switch **is** a plain Haxe `break`. |
| Go package `init()` | a lazy `init()` called from the package's entry points. |
| slice capacity reuse (`s = s[:0]`) | truncate the array when it is next used (`a.resize(0)`). |
| labeled `break`/`continue` | restructure with a flag or a local function. Mark with `// PORT: label`. |
| `switch` with `fallthrough` | duplicate the case body or use a local function. |
| goroutines, `sync.*`, `atomic.*` | sequential code / plain fields. The port is single-threaded. |
| `sync.Once`, `sync.OnceValue` | a lazy field with a null check. |

## 4a. Go runtime features with a fixed port

| Go | Haxe |
|---|---|
| `context.Context` (79 uses in scope) | shim `go.Context`: `Background()`, `TODO()`, `WithValue(ctx, key, value)`, `ctx.Value(key)`, `ctx.Err()` (always `null`, no cancellation). Keep `ctx` parameters in signatures. |
| `core.Arena[T]` | `core.Arena<T>` built with a factory: `new Arena<Type>(() -> new Type())`. `New()` returns `factory()`. `NewSlice(n)` returns an array of `n` new elements. Pointer-typed `T` (`Arena[*X]`) → factory returns `null`. |
| `core.LinkStore[K, V]` | `core.LinkStore<K, V>` built with a factory for the zero `V`; `Get` creates on first access, like Go. |
| generic code that needs `map[K]V` with a generic `K` | `go.GoMap<K, V>` (picks StringMap / IntMap / IdentityMap from the first key; one interface call per operation). `@:generic` does **not** work for classes that hold a `Map<K, V>` (Haxe 4.3.7 and 5). Concrete key types use `haxe.ds.StringMap` / `IntMap` / `go.IdentityMap` directly. **Never** `IdentityMap` for `String` keys. Struct keys: encode as a `String`. |
| `collections.Set` / `OrderedMap` / … | see the header of each class in `src/ts/collections/`. Go zero-value struct → `new Set<T>()`; Go nil pointer → `null` (only methods that Go guards with `s == nil` accept it). Collections that return Go's zero `V` take it in the constructor: `new OrderedMap<K, V>(zero)`. |
| `&x` pointer to a non-class value (`*int`, `*bool`, `&s.field`) | a small holder class or a getter/setter pair at that site. Mark `// PORT: pointer`. |

## 5. Strings (important)

Go strings are UTF-8 bytes, and TS 7 positions are **byte offsets**. TS 7 converts positions to **UTF-16** at every external edge (diagnostic columns, squiggles, source maps).

Haxe `String` is UTF-16 on JS **and** hxcpp (tested: same `length`, code units, `substring`, map keys). Therefore:

- **Positions in the Haxe port are UTF-16 code-unit offsets** (same as TS 6).
- `s[i]` (byte) → `StringTools.fastCodeAt(s, i)` (code unit). `s[a:b]` → `s.substring(a, b)`. `len(s)` → `s.length`.
- **Exception:** where a Go byte count feeds *output* (truncation limits like `typeToString`'s 320 bytes, `approximateLength`), keep UTF-8 byte semantics with `go.Utf8.ByteLen` and cut at whole characters; mark `// PORT: byte`.
- `utf8.DecodeRuneInString` and friends (about 20 files) → decode a UTF-16 surrogate pair. Use the TS 6 code (`upstream/tsc/_submodules/TypeScript/src/compiler/*.ts`) as the reference for these sites.
- `core.UTF16Len(s)` → `s.length`. `GetECMALineAndUTF16CharacterOfPosition` needs no conversion.
- Go `a < b` on strings compares bytes (= code-point order). Haxe compares UTF-16 code units. The order differs for characters above U+FFFF against U+E000–U+FFFF, and for the internal symbol prefix (Go byte 0xFE, Haxe U+FFFE, must sort above everything). **Every visible string ordering uses `go.Strings.Compare`**, which handles both.
- **U+FFFE at the output boundary:** it stands for Go's byte 0xFE. `go.Utf8.StringToBytes` (all file/stdout writes, hashes, baseline comparison) writes it as the single byte 0xFE and `go.Utf8.ByteLen` counts it as 1; code that decodes runes like Go's `utf8.DecodeRune` treats it as `utf8.RuneError` (U+FFFD, e.g. the printer's string escaping).
- **Lone surrogates (measured):** hxcpp turns a lone surrogate into U+FFFD in `String.fromCharCode`, `StringBuf.addChar` and at the edges of `substring`; then two different lone surrogates compare equal. JS keeps them. Rules:
  - Build strings from **code points**, never from single surrogate code units. Escape decoders (`\uD83D\uDE00`) must combine a high + low pair into one code point **before** they append it. Go does the same later with `CombineSurrogatePairs`.
  - Never `substring` through the middle of a surrogate pair.
  - A true lone surrogate (about 13 of 12,444 corpus files) is a **known hxcpp deviation**. These tests go on the cpp expected-failure list; JS must still pass them.
  - `go.Utf16.CodeUnitString(u)` creates a one-unit string where a lone unit is unavoidable.
- **Decoders that return `(rune, size)`** (hot paths): return the rune only; the size is `go.Utf16.RuneLen(r)`. No result object per character. Go returns size 0 at the end of the text; check the end explicitly there.
- Where Go tests a **single UTF-8 byte** with logic that is not ASCII-only (e.g. `text[pos-1]`), keep Go's byte behaviour and mark `// PORT: byte`.
- `tools/dump` (the Go reference dumper) converts its byte offsets to UTF-16 with upstream `ast.ComputePositionMap`, so dumps compare 1:1.

## 6. Generated code

Upstream generated files are not ported by hand. We generate them from the same inputs:

- `diagnostics_generated.go` → build macro `ts.diagnostics.DiagnosticsMacro` reads `diagnosticMessages.json` + `extraDiagnosticMessages.json` at compile time.
- `ast_generated.go` → generator from upstream `tsc/_scripts/ast.json` (Phase 3).
- Generated tables (`*_generated.go` with package-level vars) → one Haxe module per generated file, written by a generator in `tools/gen/<pkg>/`, with a "generated, do not edit" header. Large tables are flat `Int` arrays, decoded lazily on first use.
- Go standard library tables (e.g. `unicode` case tables) come from the pinned Go toolchain's GOROOT (`GOTOOLCHAIN=go1.26.9 go env GOROOT`).
- `*_stringer_generated.go` → hand-written `toString()` where a `String()` method is needed.

## 7. Go standard library

- Trivial calls map inline: `strings.HasPrefix` → `StringTools.startsWith`, `strings.Contains` → `s.indexOf(x) >= 0`, `math.MaxInt32` → literal, `strings.Builder` → `StringBuf`.
- Anything else goes into a shim class in `src/go/`, named after the Go package with the first letter in upper case: `go.Fmt`, `go.Strings`, `go.Unicode`, `go.Utf16`, `go.Slices`, `go.Sort`, `go.Strconv`, `go.Math`. Same function names as Go. Before you add a shim, read the file: another lane may have added it. Only add, never change an existing shim's behaviour.
- JSON output that must equal Go's byte for byte cannot use `haxe.Json` (key order undefined on cpp, different escaping). Use `ts.json.Json.MarshalOrdered` / `MarshalIndentOrdered` (Go-compatible escaping and float format; types implement `OrderedMarshaler`).
- A Go typed nil slice inside an `any` (prints `null` in JSON, unlike an empty slice) → identity sentinels, see `Tsoptions.nilAnySlice`.
- Regex patterns supplied by users at run time (preferences) go to `EReg` unchanged; RE2-only syntax is a known deviation.
- `regexp`: `go.Regexp` takes an EReg pattern that the porter rewrites to behave like Go on JS **and** hxcpp PCRE2. Rewrite rules are in the header of `src/go/Regexp.hx` (no `\d \s \w \b`, no `$`, no `i` flag). Prefer a hand loop when the pattern is simple.
- Shims must behave the same on every target (JS, hxcpp, JVM; C# and Python next).

## 7a. Toolchain

- Always build with `tools/haxe` (stock Haxe 4.3.7). It also adds `-D HXCPP_CPP17`: hxcpp's default C++11 applies **trigraphs** to string literals (`"??="` became `"#"` on cpp, measured); C++17 removes them. The `haxe` on PATH is a fork whose std needs `cpp.marshal` types that the installed hxcpp lacks (`haxe.io.Bytes`, `File.saveContent`, `sys.io.Process` do not build on cpp with it).
- hxcpp loses the sign of `-0.0` when a `Float` passes through a function value (typed or not), `Dynamic` or `Any`. Typed `Float` fields, locals and `Array<Float>` keep it. A `jsnum.Number` that can be `-0` must not travel through a closure or `Dynamic` on cpp; pass it in a typed field or call the method directly.
- **hxcpp GC and interior pointers (measured):** hxcpp's conservative stack scan recognizes pointers into the *middle* of an object only under MSVC. With GCC -O2 a closure object that is reachable only through an interior pointer while its own `_hx_run` executes was freed in use (intermittent SIGSEGV, about 1 in 3 full checker-gate runs). `tools/haxe` compiles `go.GcInit`, which calls hxcpp's `hx::RegisterVTableOffset(256)` at boot to enable interior-pointer marking (8 of 8 runs clean afterwards). Every native build must go through `tools/haxe`.
- **Function values (measured):** calling a closure costs about +3 ns on hxcpp, which is fine. But *creating* a function value allocates on every evaluation, on both targets: a lambda, a static function reference, a bound method `obj.method` (JS `$bind`, hxcpp wrapper). On hot paths (visitors, per node, per type), create the function value once (field or local outside the loop), as upstream does with cached method values.
- **Array identity on hxcpp:** inside a generic function an `Array<T>` is a `cpp.VirtualArray` wrapper, so `==` on arrays can be false for the same array. Compare array identity only with `Core.Same` (inline).
- **Zero value of a type parameter:** generic helpers that return Go's zero `T` take an optional trailing `?zero:T` (default `null`); see `Core.Find`.
- **`haxe.Int64` operators** (`&`, `.low`, even `Int64.and`) made Haxe 4.3.7 hang for over 10 minutes inside the scanner package (they compile instantly in isolation). Avoid Int64 where 32-bit Int or Float is exact; if a compile hangs, suspect Int64 first. Two measured **wrong-result** bugs: on JS, `Int64 x >>> 32` leaves an unsigned low word and a following Int64 `+` loses its carry; on hxcpp, Int64 is a signed C++ int64 and the optimizer exploits signed overflow in wrapping multiplications. For wrapping 64-bit arithmetic use 32-bit limbs (see `go.Xxh3`, `go.Slices` xorshift).
- Third-party Go modules (e.g. `zeebo/xxh3`) are ported as shims in `src/go/`, verified with a Go golden file.
- **Inferred locals from `Dynamic`/`Any`:** a local without a type annotation, initialized from a `Dynamic`/`Any` value, takes its type from a later check such as `(x : Tristate)`. On hxcpp that turns the local into `int` and converts every value (measured in `tsoptions.optionsHaveChanges`). Locals that hold a Go `any` get an explicit `:Dynamic`.
- **`String` inside modules that import `Kind.*`, `Tristate.*`, `ModuleKind.*`** (or any enum abstract with a `String()` method via wildcard): the name `String` resolves to that method, and `Std.isOfType(v, String)` even hangs Haxe 4.3.7. Write `std.String` for the type there.
- **Performance rules (Phase 9, measured on the TypeScript 6 compiler sources).** Keep Go's structure; mark each deviation `// PORT: perf` with its reason.
  - **Object-keyed maps: `go.IdentityMap`**, never `haxe.ds.ObjectMap` or `Map<SomeClass, V>`. hxcpp's ObjectMap numbers every key object through a global mutex-protected table (`__hxcpp_obj_id`, ~10 % of a check on cpp); JS ObjectMap adds an `__id__` field to each key (hidden-class change). IdentityMap hashes the address on hxcpp (safe: the GC does not move objects — `HXCPP_GC_MOVING` stays off — and the map holds its keys) and wraps an ES6 `Map` on JS. Iteration is in **insertion order** on both targets, never in address order (ASLR would make it nondeterministic). `core.LinkStore` and `go.GoMap`'s object backing use it.
  - **No threads:** `tools/haxe` builds hxcpp with `-D HXCPP_SINGLE_THREADED_APP` (hxcpp then skips a `pthread_getspecific` per allocation). Never start a `sys.thread` thread.
  - **Cutting a long text repeatedly:** Go `s[:n]` is free, hxcpp `substring` copies. For a prefix of a big text that is cut many times (the parser's per-JSDoc `sourceText[:end-2]`: 0.3 s and 330 MB on cpp) use `go.Strings.Prefix(s, n)`, a view on hxcpp. The view must never be hashed (map key, `switch`) or handed to native code that expects NUL termination; read it only with `length`, character reads, `substring`, `indexOf`.
  - **Embedded libs** are decoded per file on first read (`Bundled.embeddedContentsGet`), not all at startup.
  - **Verify every change with best-of-3 timings.** hxcpp's GC heap sizing makes peak memory and time jump by ±10 % with small changes in allocation pattern; changes that only remove a small object per call (e.g. a typed `BinarySearchFunc` without its `ValueOk`, typed comparator results in `go.Slices`) measured no gain and were dropped.
  - **Measuring (pass 2).** `tools/bench.sh <Tsgo binary | tsgo.js | go> [runs] [loads]`: best-of-N wall time and peak RSS on the realworld inputs (`decl`, `full`: TypeScript 6 compiler; `sol`: TypeScript 6 solution, `tsc -b` full clean build; `np`: native-preview). Outputs are not compared there; run the gates for that.
    - **cpp call stacks:** `tools/perf/build-fp.sh` builds `bin/perf/tsgo-cpp-fp/Tsgo` with frame pointers (C++ wrapper `tools/perf/g++-fp`; this AMD CPU has no LBR call-stack mode) and its own hxcpp config `tools/perf/hxcpp_config.xml` without the compile cache (hxcpp's cache key ignores the compiler executable, it would hand out objects without frame pointers). `perf record -F 4000 --call-graph fp -o x.data Tsgo …`, then `perf report --no-children` / `--children`, and `tools/perf/callers.py x.data '<regex>' --depth N` for the immediate callers of a hot symbol. hxcpp's GC marks and zeroes blocks on worker threads: their share of samples overstates wall time.
    - **cpp allocations:** `tools/perf/build-fp.sh --alloc` builds `bin/perf/tsgo-cpp-alloc/Tsgo` against a patched copy of hxcpp's `hx/GC.h` (a hook at the top of the inline allocator) and links `tools/perf/alloc/hook.cpp` (`--wrap` of `hx::InternalNew` / `hx::InternalRealloc` for string and array buffers): exact count and bytes per class, plus a frame-pointer stack every 64 KB allocated (`HXPERF_SAMPLE`). Run with `HXPERF_OUT=a.txt`, report with `tools/perf/allocreport.py a.txt <binary> [--class NAME] [--folded out]` (per class; per allocating site = innermost non-runtime frame; inclusive; top stacks of one class). `(unnamed)` objects are closures, Array headers and boxed values.
    - **JS:** `node --stack-size=7000 --cpu-prof --cpu-prof-dir=d tsgo.js …`, then `node tools/perf/cpuprofile.js d/*.cpuprofile [N] [--inclusive]`.
  - **hxcpp `substring` copies** (Go `s[i:]` does not): never cut the rest of a big text in a loop (`Strings.IndexAny(text.substring(i), …)` in `findImportOrRequire` was quadratic: 1.6 s and 0.9 GB of garbage per native-preview build). Use an index-based shim (`Strings.IndexAnyFrom`).
  - **Function values on hxcpp box their arguments and results**: an `Int` outside -1..255 and every `String` passed through a function value is allocated per call, and more than five arguments are packed into an `Array` per call. On hot paths use the `inline` helpers with a **lambda literal** (`Core.Filter/Map/Some/Every/Find/FindIndex`, `Slices.Contains/Index/IndexFunc/ContainsFunc/BinarySearchFuncInline`, `Ast.getCombinedFlags`): the lambda is inlined and the body is typed with the caller's element type (a non-inline generic function takes arrays as `cpp.VirtualArray` and elements as `Dynamic`). A method reference (`getNodeFlags`) is not inlined: pass `n -> getNodeFlags(n)`. A comparator closure whose callers only use the sign returns -1/0/1 (`Checker.compareSymbols`).
  - **Inline helper hazard:** an argument of type `Array<Dynamic>` does not bind the helper's `T`; if the result goes into a local without a type, a later use can bind `T` (e.g. to `String`) and the inlined body then converts every element (found by the test suite in `tsoptions`, where Go has `[]any`). Annotate such results (`final fileSpecs:Array<Dynamic> = Core.Filter(…)`). Audit: compile with `-D no-inline` and an `onAfterTyping` macro that lists calls of the inline helpers whose array argument has `Dynamic` elements.
  - **Arrays in generic classes:** in a class with type parameters, hxcpp makes `Array<T>` and also `Array<Dynamic>` fields a `cpp.VirtualArray` (a virtual call per element read). Hot generic containers keep an array of a concrete class type and read/write it untyped (`IdentityMap.SlotArray`).
  - **Iterators:** a function that returns the structure type `Iterator<T>` makes hxcpp call `hasNext`/`next` by name (two closure allocations per element). Return the concrete class (`haxe.iterators.ArrayIterator<T>`, `ECMALineStartsSeqIterator`). `for` loops over `StringMap`, `IntMap` and `IdentityMap` are rewritten on cpp by `go.ForIn` (applied through `go.NilRange`) into loops over arrays, same elements and order.
  - **Multiple results on hot paths:** `Pair`/`ValueOk` cost an object per call, plus a boxed `String`/`Int` inside (their fields are `Dynamic`). Where a function runs per node or per relation check, return one value and leave the second in a field read right after the call (`setupDiagnosticContextResult`, `Checker.getRelationKeyConstrained`), or use `null` for Go's `ok == false` (`getAccessedPropertyName`, `EmitContext.TokenSourceMapRange`). Pass 3 did the same for `addTypesToUnion`/`addTypeToUnion` (`c.addTypesToUnionIncludes`), `NodeVisitor.VisitSlice` (`VisitSliceChanged`), `isConstructorDeclaredThisProperty` (`c.isConstructorDeclaredThisPropertyLocation`) and `LineCharacterCache.getLineAndCharacter` (`lastCharacter`). Go value types without identity can be abstracts (`CacheHashKey` over its string, `KeyBuilder` over a pooled `KeyHasher`).
  - **Typed resolver hooks (approved deviation, pass 3):** Go's `binder.NameResolver` has func fields (`Lookup`, `OnSuccessfullyResolvedSymbol` with 6 arguments, …) and the checker keeps `resolveName` as a method value. On hxcpp each call boxed its `String`/`Int` arguments (and packed six arguments into an `Array`). The hooks are now overridable methods of `NameResolver` with the Go field names; the base methods do what Go does when the field is nil. The checker overrides them in `CheckerNameResolver` / `CheckerNameResolverForSuggestion` (`CheckerPart1.hx`), and `c.resolveName(...)` is an inline call of `c.nameResolver.Resolve`. Same calls in the same order. Mark: `// PORT: perf (typed resolver hooks instead of Go func fields)`.
  - **Per-call iterators:** Go's `iter.Seq` loops do not allocate; here a hot caller reuses one iterator (`ECMALineStartsSeqIterator.reset`, used by `TextWriter`) or returns a shared empty iterator (`Scanner.iterateCommentRanges` without comments). Read-only zero options are shared (`Scanner.SkipTriviaEx` with nil options).
  - **Struct keys built per lookup** (`CacheHashKey`): `KeyHasher` collects Go's exact key bytes (UTF-8 for strings) and packs them 7 bits per character into one ASCII string (narrow and short on hxcpp; injective, so key equality is byte equality as in Go up to xxh3 collisions). `haxe.io.Bytes.getString` stops at a NUL byte on JS: use `Strings.FromASCIIBytes`.
  - **Hashing:** the parser interns identifiers with `Strings.Intern` (hxcpp `String.makePermanent`: deduplicated, hash stored, never freed), so symbol-table lookups do not rehash names.
  - **GC (hxcpp immix):** `tools/haxe` sets `-D HXCPP_GC_BIG_BLOCKS` (the default 16-bit block ids cap the small-object heap at 2 GB). Heap ≈ live data × (1 + `HXCPP_TARGET_FREE_SPACE`/100), default 100; measured on TypeScript 6 decl / native-preview / solution: 50 → +8..+12 % time, −7..−24 % memory; 200 → −4..−6 % time, +15..+47 % memory; 10 → 2.0–2.5× time, −26..−43 % memory. Live data at exit after a full collection is about 190 MB for the TypeScript 6 compiler (Go's peak RSS: 375 MB); at a 10 % target the peak is still ~585 MB, so the port's live data is roughly twice Go's (object headers, `Array` objects with separate buffers, `Dynamic` fields, UTF-16 strings). hxcpp sorts all blocks on every 2 MB heap growth (`AllocMoreBlocks`, ~3–4 % at a 1 GB heap; only an hxcpp patch could remove it).
- Type names that differ only by case (`Outputpaths` / `OutputPaths`) collide in hxcpp output on case-insensitive file systems (macOS). Works on Linux; avoid new cases.
- An `inline` function that takes a lambda literal costs nothing with `-D analyzer-optimize` (the lambda is inlined).
- **Deep recursion on JS:** Go stacks grow; node's default stack does not. Deeply nested inputs (e.g. 5,000 nested binary expressions) need `node --stack-size=7000` (the gates use it; the JS launcher of the final CLI must set it too).
- **Static initialization order** across classes is not defined in Haxe. A package-level var whose initializer uses another class's statics must be a lazy getter (`static var X(get, never)`), not a `static final` with an initializer.
- A module whose Go file name clashes with a Haxe core type (`string.go`) gets a `_` suffix: `String_.hx`.
- A shim named like a std class (`go.Math`) hides the std class inside package `go`; write `std.Math` there. Use target conditionals only inside shims (`src/go/`), never in ported code. Shape: `#if cpp … #elseif js … #else <portable Haxe> #end`; the portable branch keeps Go semantics (insertion order, identity keys) and serves JVM, C# and Python. Mark target-only code `// PORT: <target> <reason>`.

## 7b. Other targets (JVM; C# and Python next)

Toolchain paths: `tools/env.sh` (overridable by environment variables). Build/run of one main on one target: `tools/targets.sh` (`hx_build`, `hx_cmd`). Gates take `--targets js,cpp,jvm,cs,py` and `--sample N`; `make matrix` writes `docs/MATRIX.md`. Rules learned on the JVM (each one measured):

- **64 KB per method.** Haxe puts all static initializers of a class into one JVM method; large literal tables overflow it (`IO.Overflow("write_ui16")` from the generator, no position). `go.JvmStatics` (applied by `go.NilRange` on JVM only) turns a static literal `Array<Int>`/`Array<String>` of 32+ constants into a decode call of a string; `DiagnosticsMacro` assigns the ~3,000 messages in chunk functions on JVM. A new large static table needs no action if it is a literal array of constants.
- **Casts are checked.** `(cast x : I)` throws `ClassCastException` when the class of `x` does not implement `I` (hxcpp and JS never check). Example: Go `TypeSystemEntity` is `any`; it is now an empty interface (`ts.ast.Symbol.TypeSystemEntity`) that `Symbol`, `NodeDefault`, `Type` and `Signature` implement.
- **Inferred locals from `Dynamic`** (§7a) also fail here: `final v = r.value; … final s:String = v;` types `v` as `String` and the JVM casts an `Array` to it (`Tsoptions.parseJsonToStringKey`). Annotate `:Dynamic`.
- **Java generics box.** A Java collection typed `IdentityHashMap<K, Int>` returns `0` for a missing key (null unboxed); declare `Null<Int>`.
- **Spread into a generic rest parameter:** `f(...ints)` with `ints:Array<Int>` and `function f<T>(...items:T)` fails JVM verification (`VerifyError: [I is not assignable to [Ljava/lang/Object;`). Pass the arguments directly, as Go does (`Compiler.plainJSErrors`).
- **Regex:** Java rejects a bare `{` (`~/{(\d+)}/`); write `~/\{([0-9]+)\}/`. Patterns must work on JS, PCRE2 (hxcpp) and `java.util.regex`.
- **Map iteration while the body changes the map** (allowed in Go): JVM's `HashMap` throws `ConcurrentModificationException`, Python's dict raises. On every target except JS, `go.ForIn` iterates `StringMap`/`IntMap` loops and `for (k in m.keys())` over snapshots (hxcpp already did).
- **`Std.string(Float)` differs per target** (`1e+21` JS, `1.0E21` JVM). Never use it for output; `go.Strconv` formats floats like Go (on JVM from `Double.toString`, the shortest round-trip digits since JDK 19, plus a 1-digit check for the JDK's 2-digit minimum: `4.9E-324` → `5e-324`).
- **Stack:** deep recursion needs `java -Xss1g` (`JAVA_OPTS` in `tools/env.sh`; the java launcher runs `main()` in a thread of that size). Parallel JVMs (checker gate `--jobs`) get `-Xmx3g -XX:ParallelGCThreads=2` each; with defaults 16 JVMs were killed by the OOM killer.
- `-Xlog:exceptions=off`: Haxe declares `throws java.lang.Object` on methods that throw a `String`; HotSpot logs a warning **to stdout** when it reflects on one (this broke the real-project stdout comparison).

## 8. Tests and lanes

- Package class name = Go package name with the first letter in upper case: `stringutil` → `ts.stringutil.Stringutil`.
- Never write into `upstream/`, not even temporarily: use `go build/run/test -overlay` with files in the scratchpad or `tools/`.
- Go `t.TempDir()` → a directory under `bin/<pkg>/tmp/`.
- Test-only Go helper packages (`testutil/parsetestutil`, `emittestutil`) → `test/ts/<pkg>/` next to the tests that use them.
- Go subtests (`t.Run("sub", ...)`) → nested `T.run("TestX/sub", ...)`.
- Upstream `*_test.go` tests for package `foo` → `test/ts/foo/FooTest.hx` with `public static function run()`; each Go test function → one `T.run("TestName", ...)` with the same name. Use `test/T.hx` (`T.eq`, `T.isTrue`, `T.fail`).
- A lane builds only its own package, into its own output directory, so lanes can run in parallel:
  ```
  tools/haxe -cp src -cp test -D analyzer-optimize -main ts.foo.FooTestMain -lib hxnodejs -js bin/foo/test.js && node bin/foo/test.js
  tools/haxe -cp src -cp test -D analyzer-optimize -main ts.foo.FooTestMain -cpp bin/foo/cpp -D HXCPP_QUIET -D HXCPP_CHECK_POINTER && bin/foo/cpp/FooTestMain
  ```
  `test/ts/foo/FooTestMain.hx` calls `FooTest.run()`, prints `T.checks`/`T.failures` and exits non-zero on failure. `test/TestMain.hx` (all packages) is wired by the lead after each wave.
- A test directory may have its own `import.hx`.
- Tests reach unexported functions with `@:allow(ts.<pkg>)` on the package class.
- `Fuzz*` functions: port as runs over their seed inputs (what `go test` does without `-fuzz`). `Benchmark*`: not ported; list them in the report.
- Each test must pass on **JS, hxcpp and JVM** (`make test`, `make test-jvm`).
- A test that cannot be ported yet (it needs an unported package) stays in the file as a comment: `// PORT: skipped, needs <pkg>`.
