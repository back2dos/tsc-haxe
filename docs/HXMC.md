# tsc-haxe on hxmc: performance log

Goal: tsc-haxe built by [hxmc](https://github.com/benmerckx/hxmc) (native Linux x86-64) at least as fast
as Go's tsgo `--singleThreaded` at parsing and type-checking the TypeScript 6 compiler sources.

Build: `tools/targets.sh` target `hxmc` (`HXMC_HOME`: an hxmc checkout with `make hxmc` done; hxmc
changes are on its branch `tsc-perf`). Output stays byte-identical to Go (stdout, exit code, every
output file) in every mode.

Workload: ts6-compiler as `tools/gate/realworld.sh` sets it up (tsconfig extending
`upstream/src/tsconfig-base.json` with `"types": []`):

- **decl**: as configured (declarations only),
- **check**: `--noEmit` (parse, bind, check),
- **full**: `--emitDeclarationOnly false --sourceMap`.

Measurement: a noisy 4-core VM (about 3x slower than the machine of UPSTREAM.md's table; a run varies
by up to 15%): wall time median (min) of 5-7 runs interleaved with Go `--singleThreaded` (go1), user
CPU, peak RSS; ratio = hxmc / go1 median wall of the same series. Instructions: callgrind, check
mode (deterministic). Go default (multithreaded) on the same machine: decl 2.09 s, full 2.95 s.

| Step | Commits (tsc-haxe / hxmc) | decl wall (min), RSS | check wall (min), RSS | full | check instr. | ratio decl / check |
|---|---|---|---|---|---|---|
| start: Go `--singleThreaded` | | 3.37-3.99 s, 407 MB | 3.6-3.8 s, 394 MB | 5.1-6.0 s, 527 MB | | |
| 0. hxmc as found (local patches) | e4b7a69 / objectmap | 5.39-5.87 s, 889 MB | 6.49 s (1 run), 892 MB | 7.58 s | 25.38 G (after 1) | 1.5 / 1.7 |
| 1. go.IdentityMap = ObjectMap on hxmc | 6cf0f03 | 5.35 s (5.03), 543 MB | 5.05 s (5.01), 539 MB | | 25.38 G | 1.44 / 1.32 |
| 2. branch threading of &&/\|\| chains, TESTI | / 760ac71 | 5.34 s (4.97), 543 MB | 5.03 s (4.89), 538 MB | | 23.57 G (-7.1%) | 1.34 / 1.37 |
| 3. JSDoc text prefix without a copy (allocation 2.1 -> 1.05 GB) | 4f6c63e | 5.20 s (4.75), 485 MB | 5.20 s (4.89), 485 MB | 7.14 s, 510 MB | 22.33 G | (noise) |
| 4. old space's first limit 512 MB (no major collection) | 9430753 / 5f0941c | 4.64 s (4.39), 394 MB | 4.34 s (4.16), 390 MB | 6.79 s, 879 MB | | 1.21 / 1.16 |

Notes per step:

1. `go.IdentityMap` had a generic branch (arrays plus an ObjectMap index); hxmc's ObjectMap is already
   insertion-ordered and hashed by address.
2. hxmc codegen: `a && b && c` materialized each intermediate boolean (setcc/movzx/test) because the
   join's phi was used twice; Opt.simplifyCfg now threads in rounds and Opt.condProp knows values
   branched on; `x & k != 0` is `test reg, k`.
3. Go slices `p.sourceText[:end-2]` per JSDoc comment; hxmc (like JVM, C#, Python) copied the file's
   text up to each comment. The scanner keeps the longer string and Go's `len(s.text)` (`textLen`).
4. The first major collection (at 256 MB) copied a live set still growing; with 512 MB the type
   check ends before any major collection. Full emit still runs one (later, so a higher peak).
