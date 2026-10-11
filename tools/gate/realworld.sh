#!/bin/sh
# Phase 8 gate: compiles real projects with the reference tsgo (Go, --singleThreaded) and with the
# Haxe tsc (JS: node --stack-size=7000 bin/realworld/tsgo-js.js, cpp: bin/realworld/tsgo-cpp/Tsgo, other
# targets: tools/targets.sh), and compares, after every step, stdout + exit code and every file of the
# working copy byte for byte. Each compiler works on its own copy (bin/realworld/w-go, w-js, w-cpp, ...);
# nothing is ever written into upstream/. --verbose build output is compared with its "hh:mm:ss AM - " clock
# prefix removed (the only nondeterministic part).
#
# Projects:
#   ts6-compiler   upstream/src/compiler (TypeScript 6 compiler sources, ~193k lines), config extends
#                  upstream/src/tsconfig-base.json with "types": [] (@types/node is not installed;
#                  the resulting errors are deterministic and part of the comparison).
#                  Modes: decl (as configured: declarations only) and full (--emitDeclarationOnly
#                  false --sourceMap). Compiled in place with outDir bin/realworld/o-<target>.
#   ts6-solution   the whole TypeScript 6 solution in build mode: tsc -b src/tsconfig.json (13
#                  projects with references: compiler, services, server, harness, testRunner, ...;
#                  ~453k lines). Copy of upstream/src + upstream/package.json +
#                  upstream/scripts/failed-tests.{cjs,d.cts}; src/compiler/diagnosticInformationMap.
#                  generated.ts is generated in the copy with upstream/scripts/processDiagnosticMessages.mjs
#                  (as upstream's hereby does). Steps: b1 clean build, b2 rebuild (--verbose, must be
#                  up to date), b3 touch src/services/services.ts + rebuild (--verbose: timestamp
#                  update only), b4 append an exported declaration to src/compiler/core.ts + rebuild
#                  (--verbose: everything downstream rebuilds). Modes: decl (as configured) and full
#                  (every step with --emitDeclarationOnly false: .js + .js.map too), plus notyp
#                  (copy without node_modules: deterministic errors in build mode; b1, b2 --verbose).
#   native-preview upstream/tsc/_packages/native-preview (JS API of tsgo, ~38k lines incl. tests):
#                  tsc -b _packages/native-preview/test (references ..; emits dist/ with declarations,
#                  declaration maps and source maps, isolatedDeclarations). Steps b1 clean, b2 rebuild
#                  (--verbose, up to date).
#   tsc-extension  upstream/tsc/_extension (VS Code extension, ~3.5k lines): tsc -p _extension, as
#                  configured (noEmit) and with emit (--noEmit false --declaration --sourceMap).
#
# Dependencies (exact versions from upstream's lock files; installed once with npm ci from the public
# registry into bin/realworld/deps/<set>/, then copied into each working copy):
#   ts6  (upstream/package-lock.json):     @types/node 25.5.0, @types/mocha 10.0.10, @types/chai 4.3.20,
#        @types/source-map-support 0.5.10, @types/ms 2.1.0, chai 4.5.0, diff 8.0.4,
#        source-map-support 0.5.21, ms 2.1.3 + their locked dependencies (19 packages)
#   tsc  (upstream/tsc/package-lock.json, with its "overrides"): @types/node 26.0.1, tinybench 6.0.2,
#        vscode-jsonrpc 9.0.0, typescript 6.0.3, @types/vscode 1.125.0, vscode-languageclient 10.0.1,
#        @vscode/extension-telemetry 1.5.2, vscode-tas-client 0.2.1 + their locked dependencies (34)
#   The lock subset (package.json + package-lock.json) is derived from upstream's lock by the node
#   snippet below (same resolution as node: nested node_modules entries included).
#
# Usage: tools/gate/realworld.sh [--no-build] [--targets LIST] [--projects LIST]
#   --no-build       reuse bin/realworld/tsgo-<target> (tools/targets.sh)
#   --targets LIST   comma separated targets (js,cpp,jvm,cs,py; default js,cpp); Go always runs
#   --projects LIST  comma separated subset of: ts6-compiler ts6-solution native-preview tsc-extension
# Exit status: 0 when every project/mode/step/target is identical to Go.
set -e
root=$(cd "$(dirname "$0")/../.." && pwd)
cd "$root"
ROOT=$root
. tools/targets.sh
out=bin/realworld
mkdir -p "$out"

build=1
targets="js cpp"
projects="ts6-compiler ts6-solution native-preview tsc-extension"
while [ $# -gt 0 ]; do
	case "$1" in
	--no-build) build=0 ;;
	--targets) targets=$(hx_list "$2"); shift ;;
	--projects) projects=$(echo "$2" | tr ',' ' '); shift ;;
	*) echo "unknown argument $1"; exit 2 ;;
	esac
	shift
done
want() { case " $projects " in *" $1 "*) return 0 ;; esac; return 1; }
main=ts.cmd.Tsgo
if [ $build = 1 ]; then
	echo "building Haxe tsc ($targets) ..."
	for t in $targets; do hx_build $t $main "$out/tsgo"; done
	[ -x .ref/tsgo ] || make ref
fi

# deps <set> <upstream lock dir> <package>...: npm ci of the lock subset into $out/deps/<set>-nm
deps() {
	set_=$1; d="$out/deps/$1-nm"; lockdir=$2; shift 2
	[ -d "$d/node_modules" ] && return 0
	rm -rf "$d"; mkdir -p "$d"
	node - "$lockdir/package-lock.json" "$d" "$@" <<'EOF'
const fs = require("fs"), path = require("path");
const [lockFile, outDir, ...roots] = process.argv.slice(2);
const lock = JSON.parse(fs.readFileSync(lockFile, "utf8")).packages;
const picked = {};
function resolve(from, name) {
	for (let p = from; ; ) {
		const k = (p ? p + "/" : "") + "node_modules/" + name;
		if (lock[k]) return k;
		if (!p) return null;
		const i = p.lastIndexOf("/node_modules/");
		p = i < 0 ? "" : p.slice(0, i);
	}
}
function add(from, name) {
	const k = resolve(from, name);
	if (!k) throw new Error("not in lock: " + name);
	if (picked[k]) return;
	const e = { ...lock[k] };
	delete e.dev; delete e.devOptional; delete e.peer;
	picked[k] = e;
	for (const d of Object.keys(e.dependencies || {})) add(k, d);
	for (const d of Object.keys(e.peerDependencies || {}))
		if (resolve(k, d) && !e.peerDependenciesMeta?.[d]?.optional) add(k, d);
}
const deps = {};
for (const r of roots) { add("", r); deps[r] = lock["node_modules/" + r].version; }
const pkg = { name: "realworld-deps", version: "0.0.0", private: true, dependencies: deps };
const up = JSON.parse(fs.readFileSync(path.join(path.dirname(lockFile), "package.json"), "utf8"));
if (up.overrides) pkg.overrides = up.overrides;
fs.writeFileSync(outDir + "/package.json", JSON.stringify(pkg, null, 2) + "\n");
fs.writeFileSync(outDir + "/package-lock.json", JSON.stringify({ name: pkg.name, version: pkg.version,
	lockfileVersion: 3, requires: true, packages: { "": { name: pkg.name, version: pkg.version, dependencies: deps }, ...picked } }, null, 2) + "\n");
EOF
	(cd "$d" && npm ci --ignore-scripts --no-audit --no-fund --loglevel=error --registry=https://registry.npmjs.org/) ||
		{ echo "npm ci failed for $set_ (network?)"; exit 2; }
}
echo "installing pinned dependencies (once) ..."
deps ts6 upstream @types/node @types/mocha @types/chai @types/source-map-support @types/ms chai diff source-map-support ms
deps tsc upstream/tsc @types/node tinybench vscode-jsonrpc typescript @types/vscode vscode-languageclient \
	@vscode/extension-telemetry vscode-tas-client

# templates (rebuilt every run from upstream)
t6="$out/deps/ts6"
rm -rf "$t6"; mkdir -p "$t6/scripts"
cp -r upstream/src upstream/package.json "$t6/"
cp upstream/scripts/failed-tests.cjs upstream/scripts/failed-tests.d.cts "$t6/scripts/"
cp -r "$out/deps/ts6-nm/node_modules" "$t6/"
node upstream/scripts/processDiagnosticMessages.mjs "$t6/src/compiler/diagnosticMessages.json" >/dev/null
tt="$out/deps/tsc"
rm -rf "$tt"; mkdir -p "$tt/_packages"
cp -r upstream/tsc/_packages/native-preview "$tt/_packages/"
cp -r upstream/tsc/_extension "$tt/"
cp -r "$out/deps/tsc-nm/node_modules" "$tt/"

status=0
fmt='%-14s %-5s %-4s %-4s %8s %8s %5s %6s %6s %s\n'
printf "$fmt" project mode step tgt seconds maxKB exit files diffs stdout

# step <project> <mode> <step> <prep command> <compiler args...>: runs the step for go, js, cpp
# (each in $out/w-<tgt>) and compares stdout+exit code and the whole working copy with Go's.
step() {
	proj=$1; mode=$2; st=$3; prep=$4; shift 4
	for tgt in go $targets; do
		w="$out/w-$tgt"
		(cd "$w" && eval "$prep")
		case $tgt in
			go)  cmd="$root/.ref/tsgo"; post=--singleThreaded ;;
			*)   cmd=$(hx_cmd $tgt $main "$root/$out/tsgo"); post= ;;
		esac
		rc=0
		# shellcheck disable=SC2086
		(cd "$w" && /usr/bin/time -f "%e %M" -o "$root/$out/time" $cmd "$@" $post > "$root/$out/raw-$tgt" 2>&1) || rc=$?
		sed -E 's/^(\x1b\[[0-9;]*m)?[0-9]{2}:[0-9]{2}:[0-9]{2} [AP]M(\x1b\[[0-9;]*m)? - //' "$out/raw-$tgt" > "$out/stdout-$tgt"
		echo "exit $rc" >> "$out/stdout-$tgt"
		read -r secs kb <<EOT
$(tail -1 "$out/time")
EOT
		files=$(find "$w" -path "$w/node_modules" -prune -o -type f -print | wc -l)
		if [ $tgt = go ]; then
			printf "$fmt" "$proj" "$mode" "$st" $tgt "$secs" "$kb" $rc "$files" - -
		else
			diffs=$(diff -rq "$out/w-go" "$w" 2>&1 | wc -l)
			same=no
			cmp -s "$out/stdout-go" "$out/stdout-$tgt" && same=yes
			printf "$fmt" "$proj" "$mode" "$st" $tgt "$secs" "$kb" $rc "$files" "$diffs" "$same"
			if [ "$diffs" != 0 ] || [ $same != yes ]; then
				status=1
				diff -rq "$out/w-go" "$w" 2>&1 | head -5 | sed 's/^/    /'
				diff "$out/stdout-go" "$out/stdout-$tgt" | head -5 | sed 's/^/    /'
			fi
		fi
	done
}
# fresh <template>: new working copies for all targets
fresh() {
	for tgt in go $targets; do rm -rf "$out/w-$tgt"; cp -r "$1" "$out/w-$tgt"; done
}

# ts6-compiler: compiled in place (sources under upstream/ are only read), outputs in w-<tgt>
src="$root/upstream/src"
want ts6-compiler && for mode in decl full; do
	extra=""
	[ $mode = full ] && extra="--emitDeclarationOnly false --sourceMap"
	for tgt in go $targets; do
		rm -rf "$out/w-$tgt"; mkdir -p "$out/w-$tgt"
		cat > "$out/w-$tgt/tsconfig.json" <<EOF
{
  "extends": "$src/tsconfig-base.json",
  "compilerOptions": { "types": [], "rootDir": "$src/compiler", "outDir": "o", "composite": false, "incremental": false, "pretty": false },
  "include": ["$src/compiler/**/*"]
}
EOF
	done
	# shellcheck disable=SC2086
	step ts6-compiler $mode b1 : -p tsconfig.json $extra
done

want ts6-solution && for mode in decl full; do
	extra=""
	[ $mode = full ] && extra="--emitDeclarationOnly false"
	fresh "$t6"
	# shellcheck disable=SC2086
	{
		step ts6-solution $mode b1 : -b src/tsconfig.json $extra
		step ts6-solution $mode b2 : -b src/tsconfig.json --verbose $extra
		step ts6-solution $mode b3 "touch src/services/services.ts" -b src/tsconfig.json --verbose $extra
		step ts6-solution $mode b4 "echo 'export const realworldGateMarker: number = 1;' >> src/compiler/core.ts" \
			-b src/tsconfig.json --verbose $extra
	}
done

# build mode with errors: no node_modules (@types/node, mocha, chai missing), pretty output from the config
if want ts6-solution; then
	fresh "$t6"
	for tgt in go $targets; do rm -rf "$out/w-$tgt/node_modules"; done
	step ts6-solution notyp b1 : -b src/tsconfig.json
	step ts6-solution notyp b2 : -b src/tsconfig.json --verbose
fi

if want native-preview; then
	fresh "$tt"
	step native-preview -    b1 : -b _packages/native-preview/test
	step native-preview -    b2 : -b _packages/native-preview/test --verbose
fi
if want tsc-extension; then
	fresh "$tt"
	step tsc-extension decl  p1 : -p _extension
	step tsc-extension emit  p1 : -p _extension --noEmit false --declaration --sourceMap
fi

exit $status
