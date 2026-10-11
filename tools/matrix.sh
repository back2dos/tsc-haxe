#!/bin/sh
# Test matrix: runs the test suites on the chosen targets and writes a Markdown table (default
# docs/MATRIX.md): rows = suites, columns = targets, each cell "pass/total", plus a time table,
# the toolchain versions and the commit. The suites are the existing gates (tools/gate/*.sh) and the
# unit tests; this script only runs them and parses their result tables.
#
# Usage: tools/matrix.sh [--targets LIST] [--suites LIST] [--sample T=N,...] [--jobs N] [--out FILE] [--no-build]
#   --targets  comma separated, from js,cpp,jvm,cs,py (default js,cpp,jvm). The table always has all
#              five columns; a target that is not run shows "—".
#   --suites   comma separated, from unit,scanner,parser,binder,printer,checker,tsc,realworld (default all)
#   --sample   per target: run only every N-th input of the corpus gates (scanner, parser, binder,
#              printer: corpus files; checker: test files; tsc: scenarios). The cell then says
#              "(1/N)". With N > 1 the realworld suite runs only the small project tsc-extension.
#              Default: py=20 (Python is slow); all other targets 1.
#   --jobs     parallel processes for the checker gate (default 16)
#   --out      output file (default docs/MATRIX.md)
#   --no-build reuse the binaries of the previous run
# Logs: bin/matrix/<suite>-<targets>.log. Exit status 0 (the table shows the failures).
set -e
root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"
ROOT=$root
. tools/targets.sh

targets="js cpp jvm"
suites="unit scanner parser binder printer checker tsc realworld"
samples="py=20"
jobs=16
outfile=docs/MATRIX.md
build=1
cmdline="tools/matrix.sh $*"
while [ $# -gt 0 ]; do
	case "$1" in
	--targets) targets=$(hx_list "$2"); shift ;;
	--suites) suites=$(echo "$2" | tr ',' ' '); shift ;;
	--sample) samples="$samples,$2"; shift ;;
	--jobs) jobs=$2; shift ;;
	--out) outfile=$2; shift ;;
	--no-build) build=0 ;;
	-h | --help) sed -n '2,22p' "$0"; exit 0 ;;
	*) echo "unknown argument $1"; exit 2 ;;
	esac
	shift
done

log=bin/matrix
mkdir -p "$log"
: >"$log/runs.txt"

# sample_of <target>: the last T=N entry for the target, else 1
sample_of() {
	_n=1
	for _e in $(echo "$samples" | tr ',' ' '); do
		case $_e in "$1="*) _n=${_e#*=} ;; esac
	done
	echo "$_n"
}

# groups: the distinct sample values of the chosen targets, each with its targets
groups() {
	for _t in $targets; do sample_of "$_t"; done | sort -un
}
targets_with_sample() {
	_r=""
	for _t in $targets; do [ "$(sample_of "$_t")" = "$1" ] && _r="$_r,$_t"; done
	echo "${_r#,}"
}

nb=""
[ $build = 0 ] && nb=--no-build

# run <suite> <targets csv> <sample> <command...>: log to bin/matrix/<suite>-<targets>.log
run() {
	_s=$1 _ts=$2 _n=$3
	shift 3
	_l="$log/$_s-$(echo "$_ts" | tr ',' '-').log"
	echo "== $_s [$_ts] sample 1/$_n: $*"
	_t0=$(date +%s)
	"$@" >"$_l" 2>&1 || true
	echo "   $(($(date +%s) - _t0)) s"
	echo "$_s $_ts $_n $_l" >>"$log/runs.txt"
}

for suite in $suites; do
	for n in $(groups); do
		ts=$(targets_with_sample "$n")
		case $suite in
		unit)
			for t in $(echo "$ts" | tr ',' ' '); do
				l="$log/unit-$t.log"
				echo "== unit [$t]"
				if [ $build = 1 ]; then hx_build "$t" TestMain bin/matrix/test -D HXCPP_CHECK_POINTER >"$l.build" 2>&1 || true; fi
				t0=$(date +%s%3N)
				# shellcheck disable=SC2046
				$(hx_cmd "$t" TestMain bin/matrix/test) >"$l" 2>&1 || true
				echo "time $t $(($(date +%s%3N) - t0))" >>"$l"
				echo "unit $t 1 $l" >>"$log/runs.txt"
			done
			;;
		scanner | parser | binder | printer | tsc)
			# shellcheck disable=SC2086
			run "$suite" "$ts" "$n" tools/gate/$suite.sh $nb --targets "$ts" --sample "$n"
			;;
		checker)
			# shellcheck disable=SC2086
			run checker "$ts" "$n" tools/gate/checker.sh $nb --targets "$ts" --jobs "$jobs" --sample "$n"
			;;
		realworld)
			p=""
			[ "$n" -gt 1 ] && p="--projects tsc-extension"
			# shellcheck disable=SC2086
			run realworld "$ts" "$n" tools/gate/realworld.sh $nb --targets "$ts" $p
			;;
		*) echo "unknown suite $suite"; exit 2 ;;
		esac
	done
done

# toolchain versions
{
	echo "haxe $(tools/haxe --version 2>&1)"
	echo "hxcpp $(haxelib path hxcpp 2>/dev/null | sed -n 's/^-D hxcpp=//p')"
	echo "hxjava $(haxelib path hxjava 2>/dev/null | sed -n 's/^-D hxjava=//p')"
	echo "hxnodejs $(haxelib path hxnodejs 2>/dev/null | sed -n 's/^-D hxnodejs=//p')"
	echo "node $($NODE --version 2>&1)"
	echo "g++ $(g++ --version 2>&1 | head -1)"
	echo "java $($JAVA -version 2>&1 | head -1)"
	echo "dotnet $($DOTNET --version 2>&1 | head -1)"
	echo "python $($PYTHON --version 2>&1)"
} >"$log/versions.txt"

commit=$(git rev-parse --short HEAD)
git diff --quiet HEAD -- src test tools Makefile *.hxml 2>/dev/null || commit="$commit + local changes"
python3 tools/matrix.py "$log/runs.txt" "$log/versions.txt" "$commit" "$cmdline" "$targets" "$outfile"
echo "wrote $outfile"
