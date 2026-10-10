#!/bin/sh
# Phase 2 gate for the scanner: dumps the raw token stream of every corpus file with the Go
# reference (.ref/tsdump-tokens) and with the Haxe port (test/ts/scanner/TokenDump.hx, JS and
# cpp builds), in normal and -trivia mode, and compares them file by file.
#
# Corpus: upstream/tsc/_submodules/TypeScript/tests/cases/{compiler,conformance}, all files
# named *.ts *.tsx *.js *.jsx *.mts *.cts (at the pin: 12114 .ts, 330 .tsx, 1 .js).
#
# Usage: tools/gate/scanner.sh [--no-build]
# Exit status: 0 when every mode/target has 0 differing files.
set -e
root=$(cd "$(dirname "$0")/../.." && pwd)
cd "$root"
out=bin/scanner/gate
mkdir -p "$out"
cases=upstream/tsc/_submodules/TypeScript/tests/cases

if [ "$1" != "--no-build" ]; then
	echo "building Haxe dumpers (JS, cpp) ..."
	tools/haxe -cp src -cp test -D analyzer-optimize -main ts.scanner.TokenDump -lib hxnodejs -js bin/scanner/dump-js.js
	tools/haxe -cp src -cp test -D analyzer-optimize -main ts.scanner.TokenDump -cpp bin/scanner/dump-cpp -D HXCPP_QUIET >/dev/null
	[ -x .ref/tsdump-tokens ] || tools/dump/build.sh
fi

find "$cases/compiler" "$cases/conformance" -type f \
	\( -name '*.ts' -o -name '*.tsx' -o -name '*.js' -o -name '*.jsx' -o -name '*.mts' -o -name '*.cts' \) |
	LC_ALL=C sort > "$out/corpus.txt"
nfiles=$(wc -l < "$out/corpus.txt")
echo "corpus: $nfiles files"

# now_ms: wall clock in milliseconds
now_ms() { date +%s%3N; }

# run <name> <command...>: output to $out/<name>.txt, prints elapsed ms
run() {
	name=$1
	shift
	t0=$(now_ms)
	"$@" > "$out/$name.txt"
	t1=$(now_ms)
	echo "$name $((t1 - t0))" >> "$out/times.txt"
}

: > "$out/times.txt"
status=0
for mode in normal trivia; do
	flag=""
	[ "$mode" = trivia ] && flag="-trivia"
	run "ref-$mode" .ref/tsdump-tokens $flag $(cat "$out/corpus.txt")
	run "js-$mode" node bin/scanner/dump-js.js $flag "@$out/corpus.txt"
	run "cpp-$mode" bin/scanner/dump-cpp/TokenDump $flag "@$out/corpus.txt"
done

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
bad = False
print(f"{'mode':8} {'target':6} {'files':>6} {'diffs':>6} {'ms':>7}")
for mode in ('normal', 'trivia'):
    ro, rf = split(f'{out}/ref-{mode}.txt')
    print(f"{mode:8} {'go':6} {len(ro):6} {'-':>6} {times['ref-'+mode]:>7}")
    for target in ('js', 'cpp'):
        to, tf = split(f'{out}/{target}-{mode}.txt')
        diffs = [f for f in ro if rf[f] != tf.get(f)]
        missing = len(ro) != len(to)
        print(f"{mode:8} {target:6} {len(to):6} {len(diffs):6} {times[target+'-'+mode]:>7}")
        for f in diffs:
            print(f"    differs: {f}")
        if diffs or missing:
            bad = True
sys.exit(1 if bad else 0)
EOF
