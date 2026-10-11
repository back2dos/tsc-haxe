package go;

// Shim for the parts of Go package runtime used by tsc --diagnostics (statistics.go).
// PORT: Go's allocator counters do not exist on JS/hxcpp. Alloc is the heap in use as reported
// by the target (node: process.memoryUsage().heapUsed; hxcpp: GC usage); Mallocs is 0 (unknown).
class MemStats {
	public var Alloc:Float = 0.0;
	public var Mallocs:Float = 0.0;

	public function new() {}
}

class Runtime {
	// runtime.GC
	public static function GC():Void {
		#if cpp
		cpp.vm.Gc.run(true);
		#end
	}

	// runtime.ReadMemStats
	public static function ReadMemStats(m:MemStats):Void {
		#if js
		final usage:Dynamic = js.Syntax.code("process.memoryUsage()");
		m.Alloc = usage.heapUsed;
		#elseif cpp
		m.Alloc = cpp.vm.Gc.memInfo64(cpp.vm.Gc.MEM_INFO_USAGE);
		#elseif jvm
		final rt = java.lang.Runtime.getRuntime();
		m.Alloc = haxe.Int64.toInt((rt.totalMemory() - rt.freeMemory()) >> 10) * 1024.0; // PORT: jvm (KB resolution)
		#end
		m.Mallocs = 0;
	}
}
