#!/bin/sh
# Profiling build of the native tsc: the release build plus frame pointers (`perf record --call-graph
# fp`; this CPU has no LBR call-stack mode) and unstripped symbols. Uses tools/perf/hxcpp_config.xml
# (no compile cache: hxcpp's cache key ignores the compiler executable).
#   tools/perf/build-fp.sh          → bin/perf/tsgo-cpp-fp/Tsgo
#   tools/perf/build-fp.sh --alloc  → bin/perf/tsgo-cpp-alloc/Tsgo: allocation profiler (see
#                                     tools/perf/alloc/hook.cpp, report with tools/perf/allocreport.py)
# Further arguments go to haxe.
root=$(cd "$(dirname "$0")/../.." && pwd)
cd "$root" || exit 1
out=bin/perf/tsgo-cpp-fp
if [ "$1" = --alloc ]; then
	shift
	out=bin/perf/tsgo-cpp-alloc
	hx=$(haxelib path hxcpp | head -1)
	inc="$root/bin/perf/hxinc"
	rm -rf "$inc"; cp -r "$hx/include" "$inc"
	# hook call at the top of the inline allocator (every hxcpp object allocation)
	python3 - "$inc/hx/GC.h" <<'PY' || exit 1
import sys
p = sys.argv[1]; s = open(p).read()
sig = "inline static void *alloc(ImmixAllocator *alloc, size_t inSize, bool inContainer, const char *inName )\n   {\n"
assert s.count(sig) == 1, "hx/GC.h changed: update tools/perf/build-fp.sh"
s = s.replace(sig, sig + "      hxperf_alloc((int)inSize, inName);\n")
s = s.replace("#define HX_GC_H\n", "#define HX_GC_H\nextern \"C\" void hxperf_alloc(int inSize, const char *inName);\n", 1)
open(p, "w").write(s)
PY
	export HXPERF_ALLOC="$inc"
fi
HXCPP_CONFIG="$root/tools/perf/hxcpp_config.xml" exec tools/haxe -main ts.cmd.Tsgo -D analyzer-optimize -cpp "$out" \
	-D HXCPP_QUIET -D "CXX=$root/tools/perf/g++-fp" -D HXCPP_DEBUG_LINK "$@"
