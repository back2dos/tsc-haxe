package go;

// PORT: ts-- — Stringutil.ContainsNonASCII in a module of its own: its code differs per target, and haxe-in-haxe's
// ts-- portable mode keeps such a module per target (tsmm.Gen.platform, tools/targets.sh).
class NonASCII {
	// PORT: utf16 — checks UTF-16 code units; a code unit >= 0x80 exactly when a UTF-8 byte >= 0x80.
	public static function Contains(s:String):Bool {
		#if (target.name == "hxmc" && !hxmc.wasm_gc)
		// PORT: perf — four UTF-16 units at a time (a whole source file's text per call)
		final n = s.length;
		final p = hxmc.rt.Str.unitsAddr(s);
		var i = 0;
		while (i + 4 <= n) {
			if ((hxmc.unsafe.Mem.getI32(p, 2 * i) | hxmc.unsafe.Mem.getI32(p, 2 * i + 4)) & 0xFF80FF80 != 0)
				break;
			i += 4;
		}
		for (j in i...n) {
			if (StringTools.fastCodeAt(s, j) >= 0x80) { // Utf16.RuneSelf (a constant: inlined in the ts--, which has no field for it)
				return true;
			}
		}
		return false;
		#else
		for (i in 0...s.length) {
			if (StringTools.fastCodeAt(s, i) >= 0x80) { // Utf16.RuneSelf (a constant: inlined in the ts--, which has no field for it)
				return true;
			}
		}
		return false;
		#end
	}
}
