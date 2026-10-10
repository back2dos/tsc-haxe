#!/bin/sh
# Phase 7 checker gate: runs the ported compiler test runner (test/ts/harness/CheckerGate.hx, on top of
# test/ts/testrunner, test/ts/testutil/{harnessutil,tsbaseline,baseline}) over all test files of
# upstream/tsc/_submodules/TypeScript/tests/cases/{compiler,conformance} (*.ts, *.tsx; with the
# @directives, multi-file splitting and configuration variants of the Go runner) and compares the
# .errors.txt, .types, .symbols, .js (incl. .d.ts output and DtsFileErrors), .js.map, .sourcemap.txt and
# .trace.json baselines with upstream/tsc/testdata/baselines/reference/submodule.
#
# Usage:
#   tools/gate/checker.sh [--no-build] [--js-only|--cpp-only] [--jobs N] [gate args...]
#       full run on JS and cpp; per kind: cases, pass, fail, crash, skip.
#       --jobs N runs N gate processes in parallel (each on every N-th test file) and merges the results.
#       Per-case results: bin/gate-checker/out-<target>/results.txt
#       ("<kind> <pass|fail|crash|skip> <suite>/<configured name> <first differing line | panic>")
#   tools/gate/checker.sh --case <name> [--case <name>...]
#       runs one test file (all its configurations) on JS and prints the full diff of every
#       differing baseline (reference vs. port output) and the full panic of every crash.
# Extra gate args: --filter <substring of the test path>, --limit <n>, --tolerate-emit-crash.
set -e
root=$(cd "$(dirname "$0")/../.." && pwd)
cd "$root"
out=bin/gate-checker
mkdir -p "$out"

build=1
targets="js cpp"
casemode=0
jobs=1
args=""
while [ $# -gt 0 ]; do
	case "$1" in
	--no-build) build=0 ;;
	--js-only) targets="js" ;;
	--cpp-only) targets="cpp" ;;
	--case) casemode=1; args="$args --case $2"; shift ;;
	--jobs) jobs=$2; shift ;;
	*) args="$args $1" ;;
	esac
	shift
done
if [ $casemode = 1 ]; then targets="js"; fi

if [ $build = 1 ]; then
	for t in $targets; do
		echo "building gate ($t) ..."
		if [ $t = js ]; then
			tools/haxe -cp src -cp test -D analyzer-optimize -main ts.harness.CheckerGate -lib hxnodejs -js $out/gate.js
		else
			tools/haxe -cp src -cp test -D analyzer-optimize -main ts.harness.CheckerGate -cpp $out/cpp -D HXCPP_QUIET -D HXCPP_CHECK_POINTER >/dev/null
		fi
	done
fi

rungate() { # target outdir args...
	t=$1
	d=$2
	shift 2
	if [ $t = js ]; then
		node --stack-size=7000 --max-old-space-size=8000 $out/gate.js --out "$d" "$@"
	else
		$out/cpp/CheckerGate --out "$d" "$@"
	fi
}

for t in $targets; do
	dir=$out/out-$t
	if [ $casemode = 1 ]; then dir=$out/case; fi
	rm -rf "$dir/local"
	echo "== $t"
	if [ $casemode = 1 ] || [ "$jobs" -le 1 ]; then
		# shellcheck disable=SC2086
		rungate $t "$dir" $args
	else
		rm -rf "$dir/shards"
		mkdir -p "$dir/shards"
		i=0
		while [ $i -lt "$jobs" ]; do
			# shellcheck disable=SC2086
			rungate $t "$dir/shards/$i" $args --shard $i/$jobs >"$dir/shards/$i.log" 2>&1 &
			i=$((i + 1))
		done
		wait
		# per-case lines in test file order (stable sort on the case name keeps the kind order)
		cat "$dir"/shards/*/results.txt | LC_ALL=C sort -s -k3,3 >"$dir/results.txt"
		mkdir -p "$dir/local"
		for s in "$dir"/shards/*; do
			if [ -d "$s/local" ]; then cp -r "$s/local/." "$dir/local/"; fi
		done
		awk '{ k[$1]=1; n[$1]++; c[$1" "$2]++ }
			END {
				printf "%-10s%-7s%-7s%-7s%-7s%-7s\n", "kind", "cases", "pass", "fail", "crash", "skip"
				split("errors types symbols js map sourcemap trace", ks, " ")
				for (i = 1; i <= 7; i++) { x = ks[i]; if (x in k) printf "%-10s%-7d%-7d%-7d%-7d%-7d\n", x, n[x], c[x" pass"], c[x" fail"], c[x" crash"], c[x" skip"] }
			}' "$dir/results.txt"
	fi
done

if [ $casemode = 1 ]; then
	ref=upstream/tsc/testdata/baselines/reference
	# every differing baseline was written to $dir/local/<same relative path> (".delete" = no baseline expected)
	find "$out/case/local" -type f 2>/dev/null | LC_ALL=C sort | while read -r f; do
		rel=${f#"$out/case/local/"}
		case "$rel" in
		*.delete)
			echo "---- ${rel%.delete}: the port produced no baseline, the reference exists"
			;;
		*)
			if [ -f "$ref/$rel" ]; then
				diff -u --label "reference/$rel" --label "port/$rel" "$ref/$rel" "$f" || true
			else
				echo "---- $rel: no reference baseline (expected <no content>); port output:"
				cat "$f"
			fi
			;;
		esac
	done
fi
