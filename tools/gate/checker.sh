#!/bin/sh
# Phase 7 checker gate: runs the ported compiler test runner (test/ts/harness/CheckerGate.hx, on top of
# test/ts/testrunner, test/ts/testutil/{harnessutil,tsbaseline,baseline}) over all test files of
# upstream/tsc/_submodules/TypeScript/tests/cases/{compiler,conformance} (*.ts, *.tsx; with the
# @directives, multi-file splitting and configuration variants of the Go runner) and compares the
# .errors.txt, .types and .symbols baselines with upstream/tsc/testdata/baselines/reference/submodule.
#
# Usage:
#   tools/gate/checker.sh [--no-build] [--js-only|--cpp-only] [gate args...]
#       full run on JS and cpp; per kind: cases, pass, fail, crash, skip.
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
args=""
while [ $# -gt 0 ]; do
	case "$1" in
	--no-build) build=0 ;;
	--js-only) targets="js" ;;
	--cpp-only) targets="cpp" ;;
	--case) casemode=1; args="$args --case $2"; shift ;;
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

for t in $targets; do
	dir=$out/out-$t
	if [ $casemode = 1 ]; then dir=$out/case; fi
	rm -rf "$dir/local"
	echo "== $t"
	if [ $t = js ]; then
		# shellcheck disable=SC2086
		node --stack-size=7000 --max-old-space-size=8000 $out/gate.js --out "$dir" $args
	else
		# shellcheck disable=SC2086
		$out/cpp/CheckerGate --out "$dir" $args
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
