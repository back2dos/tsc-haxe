#!/bin/sh
# Phase 8 gate: compiles real projects with the reference tsgo (Go, single-threaded) and with the
# Haxe tsc (JS and cpp), and compares stdout, exit code and every output file byte for byte.
#
# Projects (local, no download):
#   ts6-compiler   upstream/src/compiler (TypeScript 6 compiler sources, ~193k lines), config extends
#                  upstream/src/tsconfig-base.json with "types": [] (@types/node is not installed;
#                  the resulting errors are deterministic and part of the comparison).
#                  Two modes: as configured (declarations only) and full emit (--emitDeclarationOnly
#                  false --sourceMap).
#
# Usage: tools/gate/realworld.sh [--no-build]
# Exit status: 0 when every project/mode/target is identical to Go.
set -e
root=$(cd "$(dirname "$0")/../.." && pwd)
cd "$root"
out=bin/realworld
mkdir -p "$out"

if [ "$1" != "--no-build" ]; then
	echo "building Haxe tsc (JS, cpp) ..."
	tools/haxe -main ts.cmd.Tsgo -D analyzer-optimize -lib hxnodejs -js "$out/tsgo.js"
	tools/haxe -main ts.cmd.Tsgo -D analyzer-optimize -cpp "$out/tsgo-cpp" -D HXCPP_QUIET >/dev/null
	[ -x .ref/tsgo ] || make ref
fi

src="$root/upstream/src"
status=0
printf '%-14s %-6s %-4s %8s %8s %6s %6s %s\n' project mode tgt seconds maxKB files diffs stdout

# run <target> <config> <extra args...>: prints "seconds maxKB" to $out/time
run() {
	tgt=$1; cfg=$2; shift 2
	case $tgt in
		go)  set -- .ref/tsgo -p "$cfg" --singleThreaded "$@" ;;
		js)  set -- node --stack-size=7000 "$out/tsgo.js" -p "$cfg" "$@" ;;
		cpp) set -- "$out/tsgo-cpp/Tsgo" -p "$cfg" "$@" ;;
	esac
	/usr/bin/time -f "%e %M" -o "$out/time" "$@" > "$out/stdout-$tgt" 2>&1 || true
}

for mode in decl full; do
	extra=""
	[ $mode = full ] && extra="--emitDeclarationOnly false --sourceMap"
	for tgt in go js cpp; do
		rm -rf "$out/o-$tgt"
		cat > "$out/ts6-compiler-$tgt.json" <<EOF
{
  "extends": "$src/tsconfig-base.json",
  "compilerOptions": { "types": [], "rootDir": "$src/compiler", "outDir": "$root/$out/o-$tgt", "composite": false, "incremental": false, "pretty": false },
  "include": ["$src/compiler/**/*"]
}
EOF
		# shellcheck disable=SC2086
		run $tgt "$out/ts6-compiler-$tgt.json" $extra
		read -r secs kb <<EOT
$(tail -1 "$out/time")
EOT
		files=$(find "$out/o-$tgt" -type f 2>/dev/null | wc -l)
		if [ $tgt = go ]; then
			printf '%-14s %-6s %-4s %8s %8s %6s %6s %s\n' ts6-compiler $mode $tgt "$secs" "$kb" "$files" - -
		else
			diffs=$(diff -rq "$out/o-go" "$out/o-$tgt" 2>&1 | wc -l)
			same=no
			cmp -s "$out/stdout-go" "$out/stdout-$tgt" && same=yes
			printf '%-14s %-6s %-4s %8s %8s %6s %6s %s\n' ts6-compiler $mode $tgt "$secs" "$kb" "$files" "$diffs" "$same"
			if [ "$diffs" != 0 ] || [ $same != yes ]; then status=1; fi
		fi
	done
done
exit $status
