# Build and run one Haxe main on one target. Sourced by the gate scripts, the Makefile recipes,
# the launchers and tools/matrix.sh; the caller sets ROOT (repository root) and is in $ROOT.
#
# Targets and output paths for a main class M and an output base B (e.g. bin/scanner/dump):
#   js   B-js.js            node --stack-size=7000 $HX_NODE_OPTS B-js.js
#   cpp  B-cpp/<M>          native binary (hxcpp)
#   jvm  B-jvm.jar          $JAVA $JAVA_OPTS -jar B-jvm.jar
#   cs   B-cs/              C# sources (hxcs, -D no-compilation) + dotnet build   [lane 2: not ready]
#   py   B-py.py            $PYTHON B-py.py                                  [lane 3: not verified]
#
# hx_build <target> <main> <base> [haxe args...]   builds (quiet); exit status of the build
# hx_cmd <target> <main> <base>                    prints the command line that runs the build
# hx_targets_check <list>                          exits with a message on an unknown target name
. "$ROOT/tools/env.sh"

HX_ALL_TARGETS="js cpp jvm cs py"

hx_build() {
	_t=$1 _m=$2 _b=$3
	shift 3
	case $_t in
	js) "$ROOT/tools/haxe" -cp src -cp test -D analyzer-optimize -main "$_m" "$@" -lib hxnodejs -js "$_b-js.js" ;;
	cpp) "$ROOT/tools/haxe" -cp src -cp test -D analyzer-optimize -main "$_m" "$@" -cpp "$_b-cpp" -D HXCPP_QUIET >/dev/null ;;
	jvm) "$ROOT/tools/haxe" -cp src -cp test -D analyzer-optimize -main "$_m" "$@" --jvm "$_b-jvm.jar" ;;
	py) "$ROOT/tools/haxe" -cp src -cp test -D analyzer-optimize -main "$_m" "$@" --python "$_b-py.py" ;;
	cs)
		# TODO(lane 2): generate a .csproj for $_b-cs and build it with "$DOTNET" build.
		HAXELIB_PATH="$HAXELIB_CS" "$ROOT/tools/haxe" -cp src -cp test -D analyzer-optimize -main "$_m" "$@" --cs "$_b-cs" -D no-compilation || return 1
		echo "hx_build: the C# target is not wired yet (lane 2)" >&2
		return 1
		;;
	*)
		echo "hx_build: unknown target $_t" >&2
		return 2
		;;
	esac
}

hx_cmd() {
	_t=$1 _m=$2 _b=$3
	case $_t in
	js) echo "$NODE --stack-size=7000 ${HX_NODE_OPTS:-} $_b-js.js" ;;
	cpp) echo "$_b-cpp/${_m##*.}" ;;
	jvm) echo "$JAVA $JAVA_OPTS -jar $_b-jvm.jar" ;;
	py) echo "$PYTHON $_b-py.py" ;;
	cs) echo "false cs-not-wired-yet" ;; # TODO(lane 2)
	*) echo "false unknown-target-$_t" ;;
	esac
}

hx_targets_check() {
	for _t in $1; do
		case " $HX_ALL_TARGETS " in
		*" $_t "*) ;;
		*)
			echo "unknown target '$_t' (known: $HX_ALL_TARGETS)" >&2
			exit 2
			;;
		esac
	done
}

# hx_sample <n> <in> <out>: every n-th line of <in> (lines 1, 1+n, 1+2n, ...) into <out>.
# n = 1 copies all lines. Deterministic: the corpus lists are sorted.
hx_sample() {
	awk -v n="$1" '(NR - 1) % n == 0' "$2" >"$3"
}

# hx_list <comma or space separated list>: prints the space separated list (checked).
hx_list() {
	_l=$(echo "$1" | tr ',' ' ')
	hx_targets_check "$_l"
	echo $_l
}
