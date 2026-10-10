#!/bin/sh
# Phase 4 gate for the binder: parses and binds every corpus file and dumps the binder's results
# (symbols, symbol tables, flow graph, bind diagnostics) with the Go reference (.ref/tsdump-bind,
# source tools/dump/bind/main.go) and with the Haxe port (test/ts/binder/BindDump.hx, JS and cpp
# builds), and compares them file by file.
#
# Corpus: upstream/tsc/_submodules/TypeScript/tests/cases/{compiler,conformance}, all files
# named *.ts *.tsx *.js *.jsx *.mts *.cts (same set as tools/gate/parser.sh). The files are
# passed as absolute paths: ast.NewSourceFile requires a normalized absolute file name.
#
# The "ms" column is the wall clock of the whole dump (parse + bind + print). The Haxe dumpers
# also print their bind-only time (sum of BindSourceFile calls) to $out/<target>-bind.txt.
#
# Usage: tools/gate/binder.sh [--no-build]
# Exit status: 0 when every target has 0 differing files.
set -e
root=$(cd "$(dirname "$0")/../.." && pwd)
cd "$root"
out=bin/binder/gate
mkdir -p "$out"
cases=upstream/tsc/_submodules/TypeScript/tests/cases

if [ "$1" != "--no-build" ]; then
	echo "building Haxe dumpers (JS, cpp) ..."
	tools/haxe -cp src -cp test -D analyzer-optimize -main ts.binder.BindDump -lib hxnodejs -js bin/binder/dump-js.js
	tools/haxe -cp src -cp test -D analyzer-optimize -main ts.binder.BindDump -cpp bin/binder/dump-cpp -D HXCPP_QUIET >/dev/null
	[ -x .ref/tsdump-bind ] || tools/dump/build.sh
fi

find "$root/$cases/compiler" "$root/$cases/conformance" -type f \
	\( -name '*.ts' -o -name '*.tsx' -o -name '*.js' -o -name '*.jsx' -o -name '*.mts' -o -name '*.cts' \) |
	LC_ALL=C sort > "$out/corpus.txt"
nfiles=$(wc -l < "$out/corpus.txt")
echo "corpus: $nfiles files"

# now_ms: wall clock in milliseconds
now_ms() { date +%s%3N; }

# run <name> <command...>: output to $out/<name>.txt, stderr to $out/<name>-bind.txt, prints elapsed ms
run() {
	name=$1
	shift
	t0=$(now_ms)
	"$@" > "$out/$name.txt" 2> "$out/$name-bind.txt"
	t1=$(now_ms)
	echo "$name $((t1 - t0))" >> "$out/times.txt"
}

: > "$out/times.txt"
run ref .ref/tsdump-bind "@$out/corpus.txt"
run js node --stack-size=7000 bin/binder/dump-js.js -t "@$out/corpus.txt"
run cpp bin/binder/dump-cpp/BindDump -t "@$out/corpus.txt"

# Per-file comparison: split each dump at its "## <file>" headers.
python3 - "$out" <<'PY'
import sys
out = sys.argv[1]
def split(path):
    files = {}
    order = []
    cur = None
    with open(path, 'rb') as f:
        for line in f:
            if line.startswith(b'## '):
                cur = line[3:].rstrip(b'\n').decode()
                order.append(cur)
                files[cur] = []
            files[cur].append(line)
    return order, files
times = dict(l.split() for l in open(f'{out}/times.txt'))
def bind_ms(target):
    try:
        for l in open(f'{out}/{target}-bind.txt'):
            if l.startswith('bind ms: '):
                return l.split()[2]
    except OSError:
        pass
    return '-'
bad = False
ro, rf = split(f'{out}/ref.txt')
print(f"{'target':6} {'files':>6} {'diffs':>6} {'ms':>7} {'bind ms':>8}")
print(f"{'go':6} {len(ro):6} {'-':>6} {times['ref']:>7} {'-':>8}")
for target in ('js', 'cpp'):
    to, tf = split(f'{out}/{target}.txt')
    diffs = [f for f in ro if rf[f] != tf.get(f)]
    missing = len(ro) != len(to)
    print(f"{target:6} {len(to):6} {len(diffs):6} {times[target]:>7} {bind_ms(target):>8}")
    with open(f'{out}/{target}-diffs.txt', 'w') as d:
        for f in diffs:
            d.write(f + '\n')
    for f in diffs[:50]:
        print(f"    differs: {f}")
    if len(diffs) > 50:
        print(f"    ... {len(diffs) - 50} more (see {out}/{target}-diffs.txt)")
    if diffs or missing:
        bad = True
sys.exit(1 if bad else 0)
PY
