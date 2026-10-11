#!/bin/sh
# Phase 3 gate for the parser: dumps the AST and the parse diagnostics of every corpus file with
# the Go reference (.ref/tsdump-ast, source tools/dump/ast/main.go) and with the Haxe port
# (test/ts/parser/AstDump.hx, JS and cpp builds), and compares them file by file.
#
# Corpus: upstream/tsc/_submodules/TypeScript/tests/cases/{compiler,conformance}, all files
# named *.ts *.tsx *.js *.jsx *.mts *.cts (same set as tools/gate/scanner.sh). The files are
# passed as absolute paths: ast.NewSourceFile requires a normalized absolute file name.
#
# Usage: tools/gate/parser.sh [--no-build] [--targets LIST] [--sample N]
#   --targets LIST  comma separated targets (js,cpp,jvm,cs,py; default js,cpp; see tools/targets.sh)
#   --sample N      only every N-th corpus file (files 1, 1+N, 1+2N, ... of the sorted list; Go too)
# Exit status: 0 when every target has 0 differing files.
set -e
root=$(cd "$(dirname "$0")/../.." && pwd)
cd "$root"
ROOT=$root
. tools/targets.sh
out=bin/parser/gate
mkdir -p "$out"
cases=upstream/tsc/_submodules/TypeScript/tests/cases

build=1
targets="js cpp"
sample=1
while [ $# -gt 0 ]; do
	case "$1" in
	--no-build) build=0 ;;
	--targets) targets=$(hx_list "$2"); shift ;;
	--sample) sample=$2; shift ;;
	*) echo "unknown argument $1"; exit 2 ;;
	esac
	shift
done
main=ts.parser.AstDump
if [ $build = 1 ]; then
	echo "building Haxe dumpers ($targets) ..."
	for t in $targets; do hx_build $t $main bin/parser/dump; done
	[ -x .ref/tsdump-ast ] || tools/dump/build.sh
fi

find "$root/$cases/compiler" "$root/$cases/conformance" -type f \
	\( -name '*.ts' -o -name '*.tsx' -o -name '*.js' -o -name '*.jsx' -o -name '*.mts' -o -name '*.cts' \) |
	LC_ALL=C sort > "$out/corpus-all.txt"
nfiles=$(wc -l < "$out/corpus-all.txt")
hx_sample "$sample" "$out/corpus-all.txt" "$out/corpus.txt"
nsample=$(wc -l < "$out/corpus.txt")
echo "corpus: $nfiles files; sample 1/$sample: $nsample files"

# now_ms: wall clock in milliseconds
now_ms() { date +%s%3N; }

# run <name> <command...>: output to $out/<name>.txt, prints elapsed ms
run() {
	name=$1
	shift
	t0=$(now_ms)
	"$@" > "$out/$name.txt" || echo "$name: exit status $?" >&2
	t1=$(now_ms)
	echo "$name $((t1 - t0))" >> "$out/times.txt"
}

: > "$out/times.txt"
run ref .ref/tsdump-ast "@$out/corpus.txt"
for t in $targets; do
	# shellcheck disable=SC2046
	run $t $(hx_cmd $t $main bin/parser/dump) "@$out/corpus.txt"
done

# Per-file comparison: split each dump at its "## <file>" headers.
python3 - "$out" "$targets" <<'EOF'
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
ro, rf = split(f'{out}/ref.txt')
print(f"{'target':6} {'files':>6} {'diffs':>6} {'ms':>7}")
print(f"{'go':6} {len(ro):6} {'-':>6} {times['ref']:>7}")
for target in sys.argv[2].split():
    to, tf = split(f'{out}/{target}.txt')
    diffs = [f for f in ro if rf[f] != tf.get(f)]
    missing = len(ro) != len(to)
    print(f"{target:6} {len(to):6} {len(diffs):6} {times[target]:>7}")
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
