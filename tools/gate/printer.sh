#!/bin/sh
# Printer gate: parses and prints every corpus file with the Go reference (.ref/tsdump-print,
# source tools/dump/print/main.go) and with the Haxe port (test/ts/printer/PrintDump.hx, JS and
# cpp builds), and compares the printed text file by file. Each dumper also reports the time
# spent in Printer.EmitSourceFile only ("print-ms" on stderr; column print-ms in the table).
#
# Corpus: upstream/tsc/_submodules/TypeScript/tests/cases/{compiler,conformance}, all files
# named *.ts *.tsx *.js *.jsx *.mts *.cts (same set as tools/gate/scanner.sh). The files are
# passed as absolute paths: ast.NewSourceFile requires a normalized absolute file name.
#
# cpp is built with: under hxcpp's default -std=c++11 the C++ compiler applies
# trigraphs to generated string literals ("??=" becomes "#"), which breaks the scanner's token
# table (Scanner.TokenToString(KindQuestionQuestionEqualsToken) == "" on cpp).
#
# Usage: tools/gate/printer.sh [--no-build]
# Exit status: 0 when every target has 0 differing files.
set -e
root=$(cd "$(dirname "$0")/../.." && pwd)
cd "$root"
out=bin/printer/gate
mkdir -p "$out"
cases=upstream/tsc/_submodules/TypeScript/tests/cases

if [ "$1" != "--no-build" ]; then
	echo "building Haxe dumpers (JS, cpp) ..."
	tools/haxe -cp src -cp test -D analyzer-optimize -main ts.printer.PrintDump -lib hxnodejs -js bin/printer/dump-js.js
	tools/haxe -cp src -cp test -D analyzer-optimize -main ts.printer.PrintDump -cpp bin/printer/dump-cpp -D HXCPP_QUIET -D HXCPP_CHECK_POINTER >/dev/null
	[ -x .ref/tsdump-print ] || tools/dump/build.sh
fi

find "$root/$cases/compiler" "$root/$cases/conformance" -type f \
	\( -name '*.ts' -o -name '*.tsx' -o -name '*.js' -o -name '*.jsx' -o -name '*.mts' -o -name '*.cts' \) |
	LC_ALL=C sort > "$out/corpus.txt"
nfiles=$(wc -l < "$out/corpus.txt")
echo "corpus: $nfiles files"

# now_ms: wall clock in milliseconds
now_ms() { date +%s%3N; }

# run <name> <command...>: output to $out/<name>.txt, stderr to $out/<name>.err, elapsed ms to times.txt
run() {
	name=$1
	shift
	t0=$(now_ms)
	"$@" > "$out/$name.txt" 2> "$out/$name.err"
	t1=$(now_ms)
	echo "$name $((t1 - t0))" >> "$out/times.txt"
}

: > "$out/times.txt"
run ref .ref/tsdump-print "@$out/corpus.txt"
run js node --stack-size=7000 bin/printer/dump-js.js "@$out/corpus.txt"
run cpp bin/printer/dump-cpp/PrintDump "@$out/corpus.txt"

# Per-file comparison: split each dump at its "## <file>" headers.
python3 - "$out" <<'EOF'
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
def printms(name):
    for l in open(f'{out}/{name}.err'):
        if l.startswith('print-ms '):
            return l.split()[1]
    return '?'

bad = False
ro, rf = split(f'{out}/ref.txt')
print(f"{'target':6} {'files':>6} {'diffs':>6} {'ms':>7} {'print-ms':>8}")
print(f"{'go':6} {len(ro):6} {'-':>6} {times['ref']:>7} {printms('ref'):>8}")
for target in ('js', 'cpp'):
    to, tf = split(f'{out}/{target}.txt')
    diffs = [f for f in ro if rf[f] != tf.get(f)]
    missing = len(ro) != len(to)
    print(f"{target:6} {len(to):6} {len(diffs):6} {times[target]:>7} {printms(target):>8}")
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
EOF
