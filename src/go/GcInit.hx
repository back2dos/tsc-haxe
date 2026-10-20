package go;

// hxcpp's conservative stack scan recognizes interior pointers (a pointer into the middle of an
// object, e.g. `&this->field` kept by an optimizing compiler) only under MSVC (hxcpp Immix.cpp:
// sgCheckInternalOffset). With GCC -O2 an object that is reachable only through such a pointer —
// e.g. a closure object while its own `_hx_run` executes — can be freed while it is still in use
// (measured: intermittent SIGSEGV in NodeBuilderImpl.typeToTypeNode's closure, garbage `_gthis`).
// hx::RegisterVTableOffset is hxcpp's switch to enable interior-pointer marking up to that offset.
@:keep
class GcInit {
	static function __init__():Void {
		#if cpp
		untyped __cpp__("::hx::RegisterVTableOffset(256)");
		#elseif (target.name == "hxmc" && !hxmc.wasm_gc && hxmc.target != "wasm32-wasi")
		// PORT: perf — hxmc's first major collection runs when the old space reaches 256 MB; the
		// compiler keeps most of what it allocates (syntax trees, symbols, types) until it exits, so
		// that collection copies a live set that is still growing (ts6-compiler: 0.3 s; peak memory
		// 496 MB with it, 400 MB without). Go's collector first runs at 4 MB and then at twice the live heap.
		hxmc.rt.Gc.setOldLimit(512);
		#end
	}
}
