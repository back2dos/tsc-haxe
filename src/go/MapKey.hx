package go;

// PORT: perf — the string form of a Go struct used as a map key (PORTING.md §4a: struct keys are
// encoded as a String), from Int fields and at most one trailing string. Other targets keep the
// decimal form joined by ':'; on hxmc, whose strings are 16-bit units that need not be valid
// UTF-16, each Int is two units and the string follows: one allocation, no number formatting.
// Both forms are injective for a given field layout (each map uses one).
class MapKey {
	#if (target.name == "hxmc")
	static inline function int(d:hxmc.rt.Repr.Chars, at:Int, v:Int):Void {
		d.set(at, v & 0xFFFF);
		d.set(at + 1, v >>> 16);
	}

	public static function i2(a:Int, b:Int):String {
		final s = hxmc.rt.Str.make(4);
		final d = hxmc.rt.Str.chars(s);
		int(d, 0, a);
		int(d, 2, b);
		return s;
	}

	public static function i3(a:Int, b:Int, c:Int):String {
		final s = hxmc.rt.Str.make(6);
		final d = hxmc.rt.Str.chars(s);
		int(d, 0, a);
		int(d, 2, b);
		int(d, 4, c);
		return s;
	}

	public static function i4(a:Int, b:Int, c:Int, e:Int):String {
		final s = hxmc.rt.Str.make(8);
		final d = hxmc.rt.Str.chars(s);
		int(d, 0, a);
		int(d, 2, b);
		int(d, 4, c);
		int(d, 6, e);
		return s;
	}

	public static function i1s(a:Int, t:String):String {
		final n = t.length;
		final s = hxmc.rt.Str.make(2 + n);
		final d = hxmc.rt.Str.chars(s);
		int(d, 0, a);
		for (i in 0...n)
			d.set(2 + i, StringTools.fastCodeAt(t, i));
		return s;
	}

	public static function i3s(a:Int, b:Int, c:Int, t:String):String {
		final n = t.length;
		final s = hxmc.rt.Str.make(6 + n);
		final d = hxmc.rt.Str.chars(s);
		int(d, 0, a);
		int(d, 2, b);
		int(d, 4, c);
		for (i in 0...n)
			d.set(6 + i, StringTools.fastCodeAt(t, i));
		return s;
	}
	#else
	public static inline function i2(a:Int, b:Int):String
		return a + ":" + b;

	public static inline function i3(a:Int, b:Int, c:Int):String
		return a + ":" + b + ":" + c;

	public static inline function i4(a:Int, b:Int, c:Int, e:Int):String
		return a + ":" + b + ":" + c + ":" + e;

	public static inline function i1s(a:Int, t:String):String
		return a + ":" + t;

	public static inline function i3s(a:Int, b:Int, c:Int, t:String):String
		return a + ":" + b + ":" + c + ":" + t;
	#end
}
