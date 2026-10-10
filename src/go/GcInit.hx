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
		#end
	}
}
