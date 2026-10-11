#!/bin/sh
# Phase 9 benchmark: best-of-N wall time / peak RSS of one compiler binary on the realworld workloads
# (inputs as in tools/gate/realworld.sh; run that gate once first so bin/realworld/deps exists).
# Usage: tools/bench.sh <cpp binary | .js file | .py file | go> [runs=3] [workloads="decl full sol np"]
# Outputs land in bin/bench/w (overwritten); compare outputs with tools/gate/realworld.sh, not here.
root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root" || exit 1
bin=$1; runs=${2:-3}; loads=${3:-"decl full sol np"}
case $bin in
	go) cmd="$root/.ref/tsgo"; post=--singleThreaded ;;
	*.js) cmd="node --stack-size=7000 $(realpath "$bin")"; post= ;;
	*.py) cmd="${PYTHON:-python3} $(realpath "$bin")"; post= ;;
	*) cmd=$(realpath "$bin"); post= ;;
esac
w=bin/bench/w; src="$root/upstream/src"; t6=bin/realworld/deps/ts6; tt=bin/realworld/deps/tsc
for load in $loads; do
	best=; bestkb=
	for i in $(seq "$runs"); do
		rm -rf "$w"
		case $load in
			decl|full)
				mkdir -p "$w"
				cat > "$w/tsconfig.json" <<EOT
{
  "extends": "$src/tsconfig-base.json",
  "compilerOptions": { "types": [], "rootDir": "$src/compiler", "outDir": "o", "composite": false, "incremental": false, "pretty": false },
  "include": ["$src/compiler/**/*"]
}
EOT
				args="-p tsconfig.json"; [ $load = full ] && args="$args --emitDeclarationOnly false --sourceMap" ;;
			sol) cp -r "$t6" "$w"; args="-b src/tsconfig.json --emitDeclarationOnly false" ;;
			np) cp -r "$tt" "$w"; args="-b _packages/native-preview/test" ;;
		esac
		# shellcheck disable=SC2086
		(cd "$w" && /usr/bin/time -f "%e %M" -o "$root/bin/bench/time" $cmd $args $post >/dev/null 2>&1)
		read -r s kb <<EOT
$(tail -1 bin/bench/time)
EOT
		if [ -z "$best" ] || [ "$(echo "$s < $best" | bc)" = 1 ]; then best=$s; fi
		if [ -z "$bestkb" ] || [ "$kb" -lt "$bestkb" ]; then bestkb=$kb; fi
	done
	printf '%-5s %6.2f s %6d MB\n' "$load" "$best" $((bestkb / 1024))
done
