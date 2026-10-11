#!/bin/sh
# Gate for the tsc command line (lane C): runs the ported execute/tsctests scenarios (non-watch:
# TestTsc* in tsc_test.go, TestShowConfig, and the tsc -b scenarios TestBuild* in tscbuild_test.go)
# on an in-memory FS with the Haxe port (test/ts/execute/tsctests/TscGate.hx, JS and cpp builds) and
# compares every baseline byte for byte with upstream/tsc/testdata/baselines/reference/{tsc,tsbuild}/**
# (read in place, never copied).
#
# Usage: tools/gate/tsc.sh [--no-build] [--targets LIST | --js-only | --cpp-only] [--sample N] [--case <substring>]
#   --targets LIST      comma separated targets (js,cpp,jvm,cs,py; default js,cpp; see tools/targets.sh)
#   --sample N          only every N-th scenario (in run order)
#   --case <substring>  run only the scenarios whose baseline path or name contains <substring>
#                       and print the full diff (reference vs actual) for each non-passing one.
# Output: per target the number of scenarios, PASS, FAIL, CRASH and the list of failures.
# Actual baselines: bin/execute/gate/<target>/local/<tsc/...>. Exit status 0 when all pass.
set -e
root=$(cd "$(dirname "$0")/../.." && pwd)
cd "$root"
ROOT=$root
. tools/targets.sh
out=bin/execute/gate
mkdir -p "$out"
build=1
targets="js cpp"
case_filter=""
sample=1
while [ $# -gt 0 ]; do
	case "$1" in
		--no-build) build=0 ;;
		--js-only) targets="js" ;;
		--cpp-only) targets="cpp" ;;
		--targets) shift; targets=$(hx_list "$1") ;;
		--sample) shift; sample=$1 ;;
		--case) shift; case_filter="$1" ;;
		*) echo "unknown argument $1"; exit 2 ;;
	esac
	shift
done

main=ts.execute.tsctests.TscGate
if [ $build = 1 ]; then
	for t in $targets; do
		echo "building TscGate ($t) ..."
		hx_build $t $main $out/tscgate -D HXCPP_CHECK_POINTER
	done
fi

ref=upstream/tsc/testdata/baselines/reference
status=0
for t in $targets; do
	rm -rf "$out/$t/local"
	mkdir -p "$out/$t"
	set -- --local "$out/$t/local"
	[ -n "$case_filter" ] && set -- "$@" --case "$case_filter"
	[ "$sample" -gt 1 ] && set -- "$@" --sample "$sample"
	t0=$(date +%s%3N)
	# shellcheck disable=SC2046
	timeout "${TSC_GATE_TIMEOUT:-3600}" $(hx_cmd $t $main $out/tscgate) "$@" > "$out/$t/result.txt" 2>&1 || true
	t1=$(date +%s%3N)
	pass=$(grep -c '^PASS ' "$out/$t/result.txt" || true)
	fail=$(grep -c '^FAIL ' "$out/$t/result.txt" || true)
	crash=$(grep -c '^CRASH ' "$out/$t/result.txt" || true)
	total=$((pass + fail + crash))
	if ! grep -q '^SUMMARY ' "$out/$t/result.txt"; then
		echo "$t: run did not finish (see $out/$t/result.txt):"
		tail -5 "$out/$t/result.txt"
		status=1
	fi
	echo "$t: scenarios=$total pass=$pass fail=$fail crash=$crash ($((t1 - t0)) ms)"
	grep -E '^(FAIL|CRASH) ' "$out/$t/result.txt" | sed 's/^/    /' || true
	[ $((fail + crash)) -eq 0 ] || status=1
	if [ -n "$case_filter" ]; then
		grep -E '^(FAIL|CRASH) ' "$out/$t/result.txt" | sed -E 's/^(FAIL|CRASH) ([^ :]*).*/\2/' | while read -r p; do
			echo "=== $t: diff $ref/$p  $out/$t/local/$p"
			diff -u "$ref/$p" "$out/$t/local/$p" || true
		done
	fi
done
if [ -z "$case_filter" ]; then
	nref=$(find "$ref/tsc" -type f | wc -l)
	echo "reference baselines under $ref/tsc: $nref"
	nref=$(find "$ref/tsbuild" -type f | wc -l)
	echo "reference baselines under $ref/tsbuild: $nref"
fi
exit $status
