# haxe-ts

A Haxe port of the TypeScript 7 compiler (`tsc`, the Go version in
[microsoft/TypeScript](https://github.com/microsoft/TypeScript) at tag `v7.0.2`). The port is manual,
file by file, and keeps Go's names and control flow.

One Haxe code base compiles to five targets: **JavaScript (Node), C++ (hxcpp), JVM, C# (.NET) and
Python**. On every target the compiler gives output that is **byte-identical to the Go compiler**:
diagnostics, `.js`, `.d.ts`, source maps, `.tsbuildinfo` and the command-line output.

## Status

| | |
|---|---|
| Scope | The `tsc` command line: `tsc`, `tsc -p`, `tsc -b`, incremental builds, all compiler options, 13 locales |
| Not ported | Watch mode (`-w`), language service, LSP server, API |
| Upstream pin | `microsoft/TypeScript` tag `v7.0.2`, commit `1e4744d6` (details: [UPSTREAM.md](UPSTREAM.md)) |
| Size | about 190k lines of Go, about 185k lines of Haxe (356 files) |

Test results per target ([docs/MATRIX.md](docs/MATRIX.md) has the full table and run times):

| Suite | JS | C++ | JVM | C# | Python |
|---|---|---|---|---|---|
| Unit tests (435,940 checks; C++ 404,965) | ✓ | ✓ | ✓ | ✓ | ✓ |
| Scanner, parser, binder, printer: 12,445 corpus files each, byte-identical to Go | ✓ | ✓ | ✓ | ✓ | ✓ |
| Checker and emit: 14,915 test configurations from the upstream corpus (errors, types, symbols, js, d.ts, source maps, traces) | ✓ | ✓ | ✓ | ✓ | ✓ |
| `tsc` / `tsc -b` scenarios: 376 of 377 ¹ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Real projects: TypeScript 6 compiler and solution (453k lines, `tsc -b`), and two other projects; every output file byte-identical to Go | ✓ | ✓ | ✓ | ✓ | ✓ |

¹ The one failing scenario has a stale reference file upstream. Upstream's own Go test fails on it,
and the output of this port is identical to the real Go output.

## Performance

TypeScript 6 compiler sources (193k lines), declarations only, best of 3:

| Go (1 thread) | Go (default, multithreaded) | C++ | JVM | JS | C# | Python |
|---|---|---|---|---|---|---|
| 1.1 s | 0.6 s | 2.8 s | 3.2 s | 5.7 s | 5.6 s | 81 s |

The port is single-threaded. Go's parallel parsing and checking is replaced by sequential loops.
More numbers: [UPSTREAM.md](UPSTREAM.md#performance-phase-9-real-projects).

## Requirements

| Tool | Version | Needed for |
|---|---|---|
| [Haxe](https://haxe.org/download/) | 4.3.7 | everything |
| haxelib `hxcpp` | 4.3.x (tested with the git development branch) | C++ target |
| haxelib `hxnodejs` | 12.2.0 | JS target |
| haxelib `hxjava` | 4.2.0 | JVM target |
| haxelib `hxcs` | 4.2.0, installed project-local with `make setup-cs` | C# target |
| Node.js | 20 | JS target, real-project gate (`npm`) |
| g++ | 13 (C++17) | C++ target |
| JDK | 21 | JVM target |
| .NET SDK | 8 | C# target |
| Python | 3.12 | Python target |
| Go | 1.26.9 (`GOTOOLCHAIN` downloads it) | reference compiler and dumpers for the gates |
| git | | `make upstream` |

Linux is the tested platform. The C# file-system code calls Linux system functions.

### Toolchain paths

The scripts take each tool from `PATH`. To use other installs, set environment variables, or create
`tools/env.local.sh` (not in git):

```sh
# tools/env.local.sh — an environment variable still wins over these values
: "${HAXE_HOME:=/opt/haxe-4.3.7}"        # directory with haxe and std/
: "${JAVA:=/opt/jdk-21/bin/java}"
: "${DOTNET:=/opt/dotnet8/dotnet}"
: "${PYTHON:=/usr/bin/python3}"
```

All variables are listed in [tools/env.sh](tools/env.sh).

## Build and run

Build the compiler, then use it like `tsc`:

```sh
tools/haxe build-cpp.hxml          # C++: bin/tsgo-cpp/Tsgo
bin/tsgo-cpp/Tsgo -p path/to/tsconfig.json

tools/haxe build-js.hxml           # JS: bin/tsgo.js
tools/tsgo-js -p path/to/tsconfig.json

make cli-jvm && tools/tsgo-jvm --version
make setup-cs cli-cs && tools/tsgo-cs --version
make cli-py && tools/tsgo-py --version
```

Always build with `tools/haxe`. It adds the defines and the macro that the port needs.

## Tests

```sh
make test                          # unit tests, JS and C++
make test-jvm test-cs test-py      # unit tests, other targets
```

The gates compare the port with the Go compiler and the upstream test corpus. They need the pinned
upstream checkout and the Go reference tools:

```sh
make upstream                      # clone microsoft/TypeScript v7.0.2 into upstream/
make ref                           # build the Go reference tsgo into .ref/
tools/dump/build.sh                # build the Go reference dumpers into .ref/

make gates                         # scanner, parser, binder, printer
make gate-checker                  # checker and emit baselines (tools/gate/checker.sh --jobs 16)
make gate-tsc                      # tsc and tsc -b scenarios
make gate-realworld                # real projects (installs pinned npm dependencies into bin/)
make matrix                        # all suites on all five targets -> docs/MATRIX.md (about 40 min)
```

Each gate script accepts `--targets js,cpp,jvm,cs,py` (default `js,cpp`) and `--sample N` (every
N-th input). `tools/matrix.sh --help` lists the matrix options.

## Repository layout

| Path | Contents |
|---|---|
| `src/ts/` | The port: one Haxe package per Go package of `internal/`, one module per Go file |
| `src/go/` | Small Go runtime and standard-library shims (maps, slices, strings, `os`, `strconv`, …) |
| `std-py/` | Haxe standard-library overrides for the Python target (UTF-16 strings) |
| `test/` | Ported upstream unit tests and the test harness |
| `tools/gen/` | Generators (AST, diagnostic messages and locales, string tables, checker skeletons) |
| `tools/dump/` | Go programs that dump tokens, AST, symbols and printer output from the reference compiler |
| `tools/gate/` | Gate scripts |
| `tools/perf/`, `tools/bench.sh` | Profiling and benchmarks |
| `docs/PORTING.md` | Porting rules: Go to Haxe mapping, string positions, target rules |
| `UPSTREAM.md` | Upstream pin, gate status, performance, port status per package |

## How the port works

- Go structs become Haxe classes, Go packages become Haxe packages, names stay the same.
- Text positions are UTF-16 offsets on every target, as in TypeScript 6. Go uses UTF-8 internally
  and converts at the edges; the output is the same.
- Generated upstream code (AST, diagnostic messages) is generated again from the upstream data, not
  ported by hand.
- Deviations from Go have a `// PORT: <reason>` comment.

The full rules are in [docs/PORTING.md](docs/PORTING.md).

## License

Apache License 2.0, as the upstream TypeScript compiler. See [LICENSE](LICENSE) and
[NOTICE.txt](NOTICE.txt). The port is derived from the TypeScript source code, Copyright (c)
Microsoft Corporation. This project is not affiliated with or endorsed by Microsoft.
